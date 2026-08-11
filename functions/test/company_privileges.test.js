const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const {
  CompanyCreationError,
  companyNameSlug,
  createCompanyForCurrentUser,
} = require('../lib/company_privileges');

const uid = 'user-1';
const companyId = 'company-1';
const activityId = 'activity-1';
const nowMillis = 1_700_000_000_000;
const recentAuthTime = Math.floor(nowMillis / 1000) - 60;

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

function seedProfile(store, overrides = {}) {
  store.set(`users/${uid}`, {
    fullName: 'User One',
    email: 'user@example.com',
    companyId: '',
    role: 'user',
    membership: 'active',
    ...overrides,
  });
}

function dependencies(store, auth = {}) {
  return {
    getAuthUser: async () => ({
      emailVerified: true,
      disabled: false,
      ...auth,
    }),
    runTransaction: store.runTransaction.bind(store),
    newCompanyId: () => companyId,
    newActivityId: () => activityId,
    nowMillis: () => nowMillis,
    serverTimestamp: () => 'server-time',
  };
}

async function expectCreationError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof CompanyCreationError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

describe('company creation privilege boundary', () => {
  it('exports an App-Check-protected callable with Auth token guards', async () => {
    const https = require('firebase-functions/v2/https');
    const originalOnCall = https.onCall;
    try {
      https.onCall = (options, handler) => ({ options, handler });
      delete require.cache[require.resolve('../lib/index')];
      const callable = require('../lib/index').createCompanyForCurrentUser;
      assert.deepEqual(callable.options, {
        region: 'europe-west4',
        enforceAppCheck: true,
      });
      await assert.rejects(
        callable.handler({ auth: null }),
        (error) => error.code === 'unauthenticated' &&
          error.message === 'authentication-required',
      );
      await assert.rejects(
        callable.handler({
          auth: { uid, token: { email_verified: false } },
        }),
        (error) => error.code === 'failed-precondition' &&
          error.message === 'email-not-verified',
      );
    } finally {
      https.onCall = originalOnCall;
    }
  });

  it('atomically creates the exact owner state, projection and PII-free event', async () => {
    const store = new MemoryStore();
    seedProfile(store, {
      profileImage: `profile_images/${uid}/avatar.jpg`,
      profileImageRevision: 7,
    });

    const result = await createCompanyForCurrentUser(
      uid,
      recentAuthTime,
      { companyName: '  Acme North  ' },
      dependencies(store),
    );

    assert.deepEqual(result, {
      created: true,
      companyId,
      role: 'superadmin',
      activityId,
    });
    assert.deepEqual(store.get('companyNames/acme-north'), {
      companyId,
      createdBy: uid,
    });
    assert.deepEqual(store.get(`companies/${companyId}`), {
      name: 'Acme North',
      createdBy: uid,
      createdAt: 'server-time',
      joinPolicy: 'open',
    });
    assert.deepEqual(store.get(`companyDirectory/${companyId}`), {
      name: 'Acme North',
      joinPolicy: 'open',
    });
    assert.deepEqual(store.get(`memberDirectory/${uid}`), {
      fullName: 'User One',
      profileImage: `profile_images/${uid}/avatar.jpg`,
      profileImageRevision: 7,
      companyId,
      role: 'superadmin',
      membership: 'active',
    });
    assert.deepEqual(
      (({ companyId: id, companyName, role, membership }) => ({
        companyId: id,
        companyName,
        role,
        membership,
      }))(store.get(`users/${uid}`)),
      {
        companyId,
        companyName: 'Acme North',
        role: 'superadmin',
        membership: 'active',
      },
    );
    assert.deepEqual(
      store.get(`companies/${companyId}/activity/${activityId}`),
      {
        schemaVersion: 1,
        companyId,
        action: 'company.created',
        actorUid: uid,
        occurredAt: 'server-time',
        after: { ownerUid: uid },
      },
    );
    assert.deepEqual(
      store.lastCommittedWrites.map(({ type, path }) => [type, path]),
      [
        ['create', 'companyNames/acme-north'],
        ['create', `companies/${companyId}`],
        ['create', `companyDirectory/${companyId}`],
        ['create', `memberDirectory/${uid}`],
        ['update', `users/${uid}`],
        ['create', `companies/${companyId}/activity/${activityId}`],
      ],
    );
  });

  it('uses the existing canonical uniqueness key and rejects a taken name', async () => {
    const store = new MemoryStore();
    seedProfile(store);
    store.set(`companyNames/${companyNameSlug('Acme North')}`, {
      companyId: 'other-company',
      createdBy: 'other-user',
    });

    await expectCreationError(
      () => createCompanyForCurrentUser(
        uid,
        recentAuthTime,
        { companyName: 'Acme North' },
        dependencies(store),
      ),
      'already-exists',
      'company-name-taken',
    );
    assert.equal(store.has(`companies/${companyId}`), false);
    assert.equal(store.lastCommittedWrites.length, 0);
  });

  it('rejects every ineligible company/profile state before writing', async () => {
    const cases = [
      [{ companyId: 'existing-company' }, 'company-creation-profile-invalid'],
      [{ role: 'admin' }, 'company-creation-profile-invalid'],
      [{ membership: 'pending' }, 'company-creation-profile-invalid'],
      [{ fullName: '' }, 'company-creation-profile-invalid'],
      [{ profileImage: 'https://example.test/avatar.jpg' }, 'company-creation-profile-invalid'],
      [{ profileImageRevision: -1 }, 'company-creation-profile-invalid'],
    ];

    for (const [profile, message] of cases) {
      const store = new MemoryStore();
      seedProfile(store, profile);
      await expectCreationError(
        () => createCompanyForCurrentUser(
          uid,
          recentAuthTime,
          { companyName: 'Acme' },
          dependencies(store),
        ),
        'failed-precondition',
        message,
      );
      assert.equal(store.lastCommittedWrites.length, 0);
    }

    const missing = new MemoryStore();
    await expectCreationError(
      () => createCompanyForCurrentUser(
        uid,
        recentAuthTime,
        { companyName: 'Acme' },
        dependencies(missing),
      ),
      'failed-precondition',
      'company-creation-profile-invalid',
    );
  });

  it('rejects pending onboarding fields, including empty stale fields', async () => {
    for (const field of [
      'pendingOnboardingType',
      'pendingCompanyName',
      'pendingCompanyId',
    ]) {
      const store = new MemoryStore();
      seedProfile(store, { [field]: '' });
      await expectCreationError(
        () => createCompanyForCurrentUser(
          uid,
          recentAuthTime,
          { companyName: 'Acme' },
          dependencies(store),
        ),
        'failed-precondition',
        'onboarding-pending',
      );
      assert.equal(store.lastCommittedWrites.length, 0);
    }
  });

  it('rejects an account deletion lock or stray membership projection', async () => {
    const locked = new MemoryStore();
    seedProfile(locked);
    locked.set(`accountDeletionLocks/${uid}`, {});
    await expectCreationError(
      () => createCompanyForCurrentUser(
        uid,
        recentAuthTime,
        { companyName: 'Acme' },
        dependencies(locked),
      ),
      'failed-precondition',
      'account-deletion-started',
    );

    const projected = new MemoryStore();
    seedProfile(projected);
    projected.set(`memberDirectory/${uid}`, {});
    await expectCreationError(
      () => createCompanyForCurrentUser(
        uid,
        recentAuthTime,
        { companyName: 'Acme' },
        dependencies(projected),
      ),
      'failed-precondition',
      'company-membership-state-invalid',
    );
  });

  it('requires a current live, verified and enabled Auth account', async () => {
    for (const auth of [
      { emailVerified: false },
      { disabled: true },
    ]) {
      const store = new MemoryStore();
      seedProfile(store);
      await expectCreationError(
        () => createCompanyForCurrentUser(
          uid,
          recentAuthTime,
          { companyName: 'Acme' },
          dependencies(store, auth),
        ),
        'failed-precondition',
        'company-creation-account-unavailable',
      );
      assert.equal(store.lastCommittedWrites.length, 0);
    }

    const missingAuth = new MemoryStore();
    seedProfile(missingAuth);
    const deps = dependencies(missingAuth);
    deps.getAuthUser = async () => { throw new Error('auth-user-not-found'); };
    await expectCreationError(
      () => createCompanyForCurrentUser(
        uid,
        recentAuthTime,
        { companyName: 'Acme' },
        deps,
      ),
      'failed-precondition',
      'company-creation-account-unavailable',
    );
  });

  it('requires authentication no more than five minutes old', async () => {
    const store = new MemoryStore();
    seedProfile(store);
    await expectCreationError(
      () => createCompanyForCurrentUser(
        uid,
        Math.floor(nowMillis / 1000) - 301,
        { companyName: 'Acme' },
        dependencies(store),
      ),
      'failed-precondition',
      'recent-login-required',
    );
    assert.equal(store.lastCommittedWrites.length, 0);
  });

  it('rejects malformed or invalid company names without entering a transaction', async () => {
    const invalidPayloads = [
      null,
      {},
      { companyName: 7 },
      { companyName: 'Acme', companyId: 'client-company' },
    ];
    for (const payload of invalidPayloads) {
      const store = new MemoryStore();
      seedProfile(store);
      await expectCreationError(
        () => createCompanyForCurrentUser(
          uid,
          recentAuthTime,
          payload,
          dependencies(store),
        ),
        'invalid-argument',
        'company-creation-request-invalid',
      );
    }

    for (const name of ['', '   ', '***', 'x'.repeat(121)]) {
      const store = new MemoryStore();
      seedProfile(store);
      await expectCreationError(
        () => createCompanyForCurrentUser(
          uid,
          recentAuthTime,
          { companyName: name },
          dependencies(store),
        ),
        'invalid-argument',
        'company-name-invalid',
      );
    }
  });

  it('leaves every document unchanged when the atomic commit fails', async () => {
    const store = new MemoryStore();
    seedProfile(store);
    const before = new Map(store.documents);
    store.failCommit = true;

    await assert.rejects(
      createCompanyForCurrentUser(
        uid,
        recentAuthTime,
        { companyName: 'Acme' },
        dependencies(store),
      ),
      /injected-commit-failure/,
    );
    assert.deepEqual(store.documents, before);
    assert.equal(store.lastCommittedWrites.length, 0);
  });
});
