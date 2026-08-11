const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const {
  EmailSyncError,
  syncVerifiedEmailForUser,
} = require('../lib/email_sync');

const uid = 'user-1';
const companyId = 'company-1';
const activityId = 'activity-1';

class MemoryStore {
  constructor() {
    this.documents = new Map();
    this.lastCommittedWrites = [];
    this.failCommit = false;
  }

  set(path, data) {
    this.documents.set(path, { ...data });
  }

  get(path) {
    return this.documents.get(path);
  }

  has(path) {
    return this.documents.has(path);
  }

  async runTransaction(operation) {
    const writes = [];
    const result = await operation({
      get: async (path) => this.get(path),
      create: (path, data) => writes.push({ type: 'create', path, data }),
      update: (path, data) => writes.push({ type: 'update', path, data }),
    });
    if (this.failCommit) throw new Error('injected-commit-failure');

    for (const write of writes) {
      if (write.type === 'create') {
        if (this.has(write.path)) throw new Error(`already exists: ${write.path}`);
        this.set(write.path, write.data);
      } else {
        if (!this.has(write.path)) throw new Error(`not found: ${write.path}`);
        this.set(write.path, { ...this.get(write.path), ...write.data });
      }
    }
    this.lastCommittedWrites = writes;
    return result;
  }
}

function seedCompanyless(store, overrides = {}) {
  store.set(`users/${uid}`, {
    fullName: 'User One',
    email: 'old@example.test',
    companyId: '',
    role: 'user',
    membership: 'active',
    ...overrides,
  });
}

function seedActiveMember(store, overrides = {}) {
  const member = {
    fullName: 'User One',
    companyId,
    role: 'admin',
    membership: 'active',
    profileImage: `profile_images/${uid}/avatar.jpg`,
    profileImageRevision: 4,
  };
  store.set(`users/${uid}`, {
    email: 'old@example.test',
    companyName: 'Example',
    ...member,
    ...overrides.profile,
  });
  store.set(`memberDirectory/${uid}`, {
    ...member,
    ...overrides.directory,
  });
  store.set(`companies/${companyId}`, {
    name: 'Example',
    createdBy: 'owner-1',
    joinPolicy: 'open',
    ...overrides.company,
  });
}

function dependencies(store, auth = {}, hooks = {}) {
  return {
    getAuthUser: async () => {
      hooks.authCalls?.push(uid);
      if (auth.throws) throw new Error('auth-user-not-found');
      return {
        email: 'new@example.test',
        emailVerified: true,
        disabled: false,
        ...auth,
      };
    },
    runTransaction: store.runTransaction.bind(store),
    newActivityId: () => {
      hooks.activityCalls?.push(true);
      return activityId;
    },
    serverTimestamp: () => 'server-time',
  };
}

async function expectSyncError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof EmailSyncError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

describe('verified email synchronization boundary', () => {
  it('exports an App-Check-protected callable with Auth token guards', async () => {
    const https = require('firebase-functions/v2/https');
    const originalOnCall = https.onCall;
    try {
      https.onCall = (options, handler) => ({ options, handler });
      delete require.cache[require.resolve('../lib/index')];
      const callable = require('../lib/index').syncVerifiedEmail;
      assert.deepEqual(callable.options, {
        region: 'europe-west4',
        enforceAppCheck: true,
      });
      await assert.rejects(
        callable.handler({ auth: null, data: {} }),
        (error) => error.code === 'unauthenticated' &&
          error.message === 'authentication-required',
      );
      await assert.rejects(
        callable.handler({
          auth: { uid, token: { email_verified: false } },
          data: {},
        }),
        (error) => error.code === 'failed-precondition' &&
          error.message === 'email-not-verified',
      );
    } finally {
      https.onCall = originalOnCall;
    }
  });

  it('accepts only the exact empty request before reading Auth', async () => {
    for (const payload of [
      undefined,
      null,
      [],
      { email: 'new@example.test' },
      { uid },
      { companyId },
    ]) {
      const store = new MemoryStore();
      seedCompanyless(store);
      const authCalls = [];
      await expectSyncError(
        () => syncVerifiedEmailForUser(
          uid,
          payload,
          dependencies(store, {}, { authCalls }),
        ),
        'invalid-argument',
        'email-sync-request-invalid',
      );
      assert.deepEqual(authCalls, []);
      assert.equal(store.lastCommittedWrites.length, 0);
    }
  });

  it('does nothing and creates no duplicate event when the exact email matches', async () => {
    const store = new MemoryStore();
    seedActiveMember(store, {
      profile: { email: 'new@example.test' },
    });
    const activityCalls = [];

    const result = await syncVerifiedEmailForUser(
      uid,
      {},
      dependencies(store, {}, { activityCalls }),
    );

    assert.deepEqual(result, { synced: true, changed: false });
    assert.deepEqual(activityCalls, []);
    assert.deepEqual(store.lastCommittedWrites, []);
    assert.equal(
      [...store.documents.keys()].some((path) => path.includes('/activity/')),
      false,
    );
  });

  it('updates only the private email for a companyless account', async () => {
    const store = new MemoryStore();
    seedCompanyless(store);

    const result = await syncVerifiedEmailForUser(
      uid,
      {},
      dependencies(store),
    );

    assert.deepEqual(result, { synced: true, changed: true });
    assert.equal(store.get(`users/${uid}`).email, 'new@example.test');
    assert.deepEqual(
      store.lastCommittedWrites.map(({ type, path, data }) => [type, path, data]),
      [['update', `users/${uid}`, { email: 'new@example.test' }]],
    );
  });

  it('atomically appends an actor-only PII-free event for an active member', async () => {
    const store = new MemoryStore();
    seedActiveMember(store);

    const result = await syncVerifiedEmailForUser(
      uid,
      {},
      dependencies(store),
    );

    assert.deepEqual(result, { synced: true, changed: true });
    assert.equal(store.get(`users/${uid}`).email, 'new@example.test');
    assert.deepEqual(
      store.get(`companies/${companyId}/activity/${activityId}`),
      {
        schemaVersion: 1,
        companyId,
        action: 'account.email_changed',
        actorUid: uid,
        occurredAt: 'server-time',
      },
    );
    assert.deepEqual(
      store.lastCommittedWrites.map(({ type, path }) => [type, path]),
      [
        ['update', `users/${uid}`],
        ['create', `companies/${companyId}/activity/${activityId}`],
      ],
    );
    const serializedEvent = JSON.stringify(
      store.get(`companies/${companyId}/activity/${activityId}`),
    );
    assert.equal(serializedEvent.includes('old@example.test'), false);
    assert.equal(serializedEvent.includes('new@example.test'), false);
    assert.equal(serializedEvent.includes('before'), false);
    assert.equal(serializedEvent.includes('after'), false);
  });

  it('syncs without an event for malformed or cross-company projections', async () => {
    const cases = [
      {
        name: 'cross-company directory',
        mutate: (store) => {
          store.get(`memberDirectory/${uid}`).companyId = 'other-company';
        },
      },
      {
        name: 'role mismatch',
        mutate: (store) => {
          store.get(`memberDirectory/${uid}`).role = 'user';
        },
      },
      {
        name: 'unexpected projection field',
        mutate: (store) => {
          store.get(`memberDirectory/${uid}`).email = 'leak@example.test';
        },
      },
      {
        name: 'pending profile',
        mutate: (store) => {
          store.get(`users/${uid}`).membership = 'pending';
          store.get(`memberDirectory/${uid}`).membership = 'pending';
        },
      },
      {
        name: 'missing directory',
        mutate: (store) => {
          store.documents.delete(`memberDirectory/${uid}`);
        },
      },
      {
        name: 'missing company',
        mutate: (store) => {
          store.documents.delete(`companies/${companyId}`);
        },
      },
      {
        name: 'closing company',
        mutate: (store) => {
          store.get(`companies/${companyId}`).deletionScheduledFor = 'later';
          store.get(`companies/${companyId}`).deletionRequestedBy = 'owner-1';
        },
      },
      {
        name: 'malformed present-null lifecycle marker',
        mutate: (store) => {
          store.get(`companies/${companyId}`).purgeStartedAt = null;
        },
      },
      {
        name: 'banned member',
        mutate: (store) => {
          store.set(`companies/${companyId}/bans/${uid}`, { bannedBy: 'owner-1' });
        },
      },
    ];

    for (const testCase of cases) {
      const store = new MemoryStore();
      seedActiveMember(store);
      testCase.mutate(store);

      const result = await syncVerifiedEmailForUser(
        uid,
        {},
        dependencies(store),
      );

      assert.deepEqual(result, { synced: true, changed: true }, testCase.name);
      assert.equal(store.get(`users/${uid}`).email, 'new@example.test');
      assert.deepEqual(
        store.lastCommittedWrites.map(({ type, path }) => [type, path]),
        [['update', `users/${uid}`]],
        testCase.name,
      );
    }
  });

  it('rejects a deletion lock or missing private profile without writing', async () => {
    const locked = new MemoryStore();
    seedCompanyless(locked);
    locked.set(`accountDeletionLocks/${uid}`, {});
    await expectSyncError(
      () => syncVerifiedEmailForUser(uid, {}, dependencies(locked)),
      'failed-precondition',
      'account-deletion-started',
    );
    assert.equal(locked.get(`users/${uid}`).email, 'old@example.test');

    const missing = new MemoryStore();
    await expectSyncError(
      () => syncVerifiedEmailForUser(uid, {}, dependencies(missing)),
      'failed-precondition',
      'email-sync-profile-missing',
    );
    assert.equal(missing.lastCommittedWrites.length, 0);
  });

  it('requires a live enabled, verified Auth user with a nonempty email', async () => {
    for (const auth of [
      { throws: true },
      { disabled: true },
      { emailVerified: false },
      { email: undefined },
      { email: '' },
      { email: '   ' },
    ]) {
      const store = new MemoryStore();
      seedCompanyless(store);
      await expectSyncError(
        () => syncVerifiedEmailForUser(uid, {}, dependencies(store, auth)),
        'failed-precondition',
        'email-sync-account-unavailable',
      );
      assert.equal(store.get(`users/${uid}`).email, 'old@example.test');
      assert.equal(store.lastCommittedWrites.length, 0);
    }
  });

  it('does not expose an email change or event when commit fails', async () => {
    const store = new MemoryStore();
    seedActiveMember(store);
    store.failCommit = true;

    await assert.rejects(
      () => syncVerifiedEmailForUser(uid, {}, dependencies(store)),
      /injected-commit-failure/,
    );

    assert.equal(store.get(`users/${uid}`).email, 'old@example.test');
    assert.equal(
      store.has(`companies/${companyId}/activity/${activityId}`),
      false,
    );
  });
});
