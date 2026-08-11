const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const {
  OwnershipTransferError,
  transferCompanyOwnershipForUser,
} = require('../lib/ownership_transfer');
const {
  establishAccountDeletionWriteBarrier,
} = require('../lib/account_deletion');

const ownerUid = 'owner-1';
const targetUid = 'member-1';
const otherUid = 'member-2';
const companyId = 'company-1';
const activityId = 'activity-1';
const nowMillis = 1_700_000_000_000;
const recentAuthTime = Math.floor(nowMillis / 1000) - 60;
const deletedField = Symbol('delete-field');

class MemoryStore {
  constructor() {
    this.documents = new Map();
    this.lastCommittedWrites = [];
    this.failCommit = false;
    this.nameLockResult = null;
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
      listCompanyNameLocks: async (requestedCompanyId) => {
        if (this.nameLockResult) return this.nameLockResult;
        return [...this.documents.entries()]
          .filter(([path, data]) =>
            path.startsWith('companyNames/') &&
            data.companyId === requestedCompanyId)
          .map(([path, data]) => ({ path, data }));
      },
      create: (path, data) => writes.push({ type: 'create', path, data }),
      update: (path, data) => writes.push({ type: 'update', path, data }),
    });
    if (this.failCommit) throw new Error('injected-commit-failure');

    for (const write of writes) {
      if (write.type === 'create') {
        if (this.has(write.path)) throw new Error(`already exists: ${write.path}`);
        this.set(write.path, write.data);
        continue;
      }
      if (!this.has(write.path)) throw new Error(`not found: ${write.path}`);
      const next = { ...this.get(write.path) };
      for (const [key, value] of Object.entries(write.data)) {
        if (value === deletedField) delete next[key];
        else next[key] = value;
      }
      this.set(write.path, next);
    }
    this.lastCommittedWrites = writes;
    return result;
  }
}

function seedMember(store, uid, overrides = {}) {
  const member = {
    fullName: uid === ownerUid ? 'Owner One' : 'Member One',
    companyId,
    role: uid === ownerUid ? 'superadmin' : 'user',
    membership: 'active',
    ...overrides,
  };
  store.set(`users/${uid}`, { email: `${uid}@example.test`, ...member });
  store.set(`memberDirectory/${uid}`, member);
}

function seed(store) {
  seedMember(store, ownerUid);
  seedMember(store, targetUid);
  store.set(`companies/${companyId}`, {
    name: 'Example',
    createdBy: ownerUid,
    joinPolicy: 'open',
  });
  store.set('companyNames/example', { companyId, createdBy: ownerUid });
}

function dependencies(store, options = {}) {
  return {
    getAuthUser: async (uid) => {
      options.authCalls?.push(uid);
      const override = options.authByUid?.[uid];
      if (override?.throws) throw new Error('auth-user-not-found');
      return {
        emailVerified: true,
        disabled: false,
        ...override,
      };
    },
    runTransaction: store.runTransaction.bind(store),
    newActivityId: () => activityId,
    nowMillis: () => nowMillis,
    serverTimestamp: () => 'server-time',
    timestampFromMillis: Timestamp.fromMillis,
    deleteField: () => deletedField,
  };
}

function accountDeletionDb(store) {
  const reference = (path) => ({ path });
  return {
    collection: (name) => ({
      doc: (id) => reference(`${name}/${id}`),
      where: (field, operator, value) => ({ name, field, operator, value }),
    }),
    runTransaction: async (operation) => operation({
      get: async (query) => {
        assert.deepEqual(
          [query.name, query.field, query.operator],
          ['companies', 'createdBy', '=='],
        );
        const docs = [...store.documents.entries()]
          .filter(([path, data]) =>
            /^companies\/[^/]+$/.test(path) && data.createdBy === query.value)
          .map(([path]) => ({ id: path.split('/')[1], ref: reference(path) }));
        return { docs, empty: docs.length === 0, size: docs.length };
      },
      set: (ref, data) => store.set(ref.path, data),
      update: (ref, data) => store.set(ref.path, {
        ...store.get(ref.path),
        ...data,
      }),
    }),
  };
}

async function request(store, target = targetUid, options = {}) {
  return transferCompanyOwnershipForUser(
    ownerUid,
    recentAuthTime,
    { action: 'request', targetUid: target },
    dependencies(store, options),
  );
}

async function accept(store, uid = targetUid, options = {}) {
  return transferCompanyOwnershipForUser(
    uid,
    recentAuthTime,
    { action: 'accept' },
    dependencies(store, options),
  );
}

async function expectTransferError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof OwnershipTransferError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

describe('ownership transfer privilege boundary', () => {
  it('exports an App-Check-protected callable with Auth token guards', async () => {
    const https = require('firebase-functions/v2/https');
    const originalOnCall = https.onCall;
    try {
      https.onCall = (options, handler) => ({ options, handler });
      delete require.cache[require.resolve('../lib/index')];
      const callable = require('../lib/index').transferCompanyOwnership;
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
          auth: { uid: ownerUid, token: { email_verified: false } },
        }),
        (error) => error.code === 'failed-precondition' &&
          error.message === 'email-not-verified',
      );
    } finally {
      https.onCall = originalOnCall;
    }
  });

  it('creates and replaces only the exact 48-hour server-owned offer', async () => {
    const store = new MemoryStore();
    seed(store);

    const result = await request(store);

    assert.deepEqual(result, {
      requested: true,
      companyId,
      targetUid,
      expiresAtMillis: nowMillis + 48 * 60 * 60 * 1000,
    });
    const offer = store.get(`companies/${companyId}`).ownershipTransfer;
    assert.deepEqual(
      {
        fromUid: offer.fromUid,
        targetUid: offer.targetUid,
        requestedAtMillis: offer.requestedAt.toMillis(),
        expiresAtMillis: offer.expiresAt.toMillis(),
      },
      {
        fromUid: ownerUid,
        targetUid,
        requestedAtMillis: nowMillis,
        expiresAtMillis: nowMillis + 48 * 60 * 60 * 1000,
      },
    );
    assert.deepEqual(store.lastCommittedWrites.map(({ type, path }) => [type, path]), [
      ['update', `companies/${companyId}`],
    ]);
    assert.equal(
      [...store.documents.keys()].some((path) => path.includes('/activity/')),
      false,
    );

    seedMember(store, otherUid);
    const replaced = await request(store, otherUid);
    assert.equal(replaced.targetUid, otherUid);
    assert.equal(
      store.get(`companies/${companyId}`).ownershipTransfer.targetUid,
      otherUid,
    );
  });

  it('accepts atomically and moves both ownership pointers and role projections', async () => {
    const store = new MemoryStore();
    seed(store);
    await request(store);

    const result = await accept(store);

    assert.deepEqual(result, {
      transferred: true,
      companyId,
      formerOwnerUid: ownerUid,
      newOwnerUid: targetUid,
      activityId,
    });
    assert.equal(store.get(`companies/${companyId}`).createdBy, targetUid);
    assert.equal(
      Object.hasOwn(store.get(`companies/${companyId}`), 'ownershipTransfer'),
      false,
    );
    assert.equal(store.get('companyNames/example').createdBy, targetUid);
    assert.equal(store.get(`users/${ownerUid}`).role, 'admin');
    assert.equal(store.get(`memberDirectory/${ownerUid}`).role, 'admin');
    assert.equal(store.get(`users/${targetUid}`).role, 'superadmin');
    assert.equal(store.get(`memberDirectory/${targetUid}`).role, 'superadmin');
    assert.deepEqual(
      store.get(`companies/${companyId}/activity/${activityId}`),
      {
        schemaVersion: 1,
        companyId,
        action: 'company.ownership_transferred',
        actorUid: ownerUid,
        targetUid,
        occurredAt: 'server-time',
        before: { ownerUid },
        after: { ownerUid: targetUid },
      },
    );
    assert.deepEqual(store.lastCommittedWrites.map(({ type, path }) => [type, path]), [
      ['update', `companies/${companyId}`],
      ['update', 'companyNames/example'],
      ['update', `users/${ownerUid}`],
      ['update', `memberDirectory/${ownerUid}`],
      ['update', `users/${targetUid}`],
      ['update', `memberDirectory/${targetUid}`],
      ['create', `companies/${companyId}/activity/${activityId}`],
    ]);
  });

  it('moves the trusted account-deletion owner barrier to the new owner', async () => {
    const store = new MemoryStore();
    seed(store);
    await request(store);
    await accept(store);
    const db = accountDeletionDb(store);

    const formerOwnerCompanies = await establishAccountDeletionWriteBarrier(
      db,
      ownerUid,
      true,
      nowMillis,
    );
    const newOwnerCompanies = await establishAccountDeletionWriteBarrier(
      db,
      targetUid,
      true,
      nowMillis,
    );

    assert.deepEqual(formerOwnerCompanies, []);
    assert.deepEqual(
      newOwnerCompanies.map(({ id, ref }) => [id, ref.path]),
      [[companyId, `companies/${companyId}`]],
    );
  });

  it('requires exact payloads, recent authentication and live verified accounts', async () => {
    for (const payload of [
      null,
      {},
      { action: 'unknown' },
      { action: 'accept', targetUid },
      { action: 'request' },
      { action: 'request', targetUid: 'bad/path' },
      { action: 'request', targetUid, companyId },
    ]) {
      const store = new MemoryStore();
      seed(store);
      await assert.rejects(
        () => transferCompanyOwnershipForUser(
          ownerUid,
          recentAuthTime,
          payload,
          dependencies(store),
        ),
        (error) => error instanceof OwnershipTransferError &&
          error.code === 'invalid-argument',
      );
      assert.equal(store.lastCommittedWrites.length, 0);
    }

    const stale = new MemoryStore();
    seed(stale);
    await expectTransferError(
      () => transferCompanyOwnershipForUser(
        ownerUid,
        Math.floor(nowMillis / 1000) - 301,
        { action: 'request', targetUid },
        dependencies(stale),
      ),
      'failed-precondition',
      'recent-login-required',
    );

    for (const [authByUid, message] of [
      [{ [ownerUid]: { emailVerified: false } }, 'ownership-transfer-account-unavailable'],
      [{ [ownerUid]: { disabled: true } }, 'ownership-transfer-account-unavailable'],
      [{ [targetUid]: { throws: true } }, 'ownership-transfer-target-account-unavailable'],
      [{ [targetUid]: { disabled: true } }, 'ownership-transfer-target-account-unavailable'],
    ]) {
      const store = new MemoryStore();
      seed(store);
      await expectTransferError(
        () => request(store, targetUid, { authByUid }),
        'failed-precondition',
        message,
      );
      assert.equal(store.lastCommittedWrites.length, 0);
    }
  });

  it('allows only the current owner to select an eligible active member', async () => {
    const cases = [
      {
        mutate: (store) => {
          store.get(`users/${ownerUid}`).role = 'admin';
          store.get(`memberDirectory/${ownerUid}`).role = 'admin';
        },
        target: targetUid,
        code: 'permission-denied',
        message: 'company-owner-required',
      },
      {
        mutate: () => {},
        target: ownerUid,
        code: 'permission-denied',
        message: 'ownership-transfer-target-unavailable',
      },
      {
        mutate: (store) => {
          store.get(`users/${targetUid}`).membership = 'pending';
          store.get(`memberDirectory/${targetUid}`).membership = 'pending';
        },
        target: targetUid,
        code: 'permission-denied',
        message: 'ownership-transfer-target-unavailable',
      },
      {
        mutate: (store) => {
          store.get(`users/${targetUid}`).companyId = 'other-company';
          store.get(`memberDirectory/${targetUid}`).companyId = 'other-company';
        },
        target: targetUid,
        code: 'permission-denied',
        message: 'ownership-transfer-target-unavailable',
      },
      {
        mutate: (store) => store.set(
          `companies/${companyId}/bans/${targetUid}`,
          {},
        ),
        target: targetUid,
        code: 'permission-denied',
        message: 'ownership-transfer-target-unavailable',
      },
      {
        mutate: (store) => store.set(`accountDeletionLocks/${targetUid}`, {}),
        target: targetUid,
        code: 'failed-precondition',
        message: 'ownership-transfer-target-account-deleting',
      },
      {
        mutate: (store) => {
          store.get(`companies/${companyId}`).deletionScheduledFor =
            Timestamp.fromMillis(nowMillis + 1);
        },
        target: targetUid,
        code: 'failed-precondition',
        message: 'company-closing',
      },
    ];

    for (const testCase of cases) {
      const store = new MemoryStore();
      seed(store);
      testCase.mutate(store);
      await expectTransferError(
        () => request(store, testCase.target),
        testCase.code,
        testCase.message,
      );
      assert.equal(store.lastCommittedWrites.length, 0);
    }
  });

  it('does not probe Auth for an arbitrary cross-company target UID', async () => {
    const store = new MemoryStore();
    seed(store);
    store.get(`users/${targetUid}`).companyId = 'other-company';
    store.get(`memberDirectory/${targetUid}`).companyId = 'other-company';
    const authCalls = [];

    await expectTransferError(
      () => request(store, targetUid, {
        authCalls,
        authByUid: { [targetUid]: { throws: true } },
      }),
      'permission-denied',
      'ownership-transfer-target-unavailable',
    );

    assert.deepEqual(authCalls, [ownerUid]);
    assert.equal(store.lastCommittedWrites.length, 0);
  });

  it('accepts only the intended recipient before expiry with unchanged canonical state', async () => {
    const noOffer = new MemoryStore();
    seed(noOffer);
    await expectTransferError(
      () => accept(noOffer),
      'failed-precondition',
      'ownership-transfer-not-requested',
    );

    const wrongRecipient = new MemoryStore();
    seed(wrongRecipient);
    seedMember(wrongRecipient, otherUid);
    await request(wrongRecipient);
    await expectTransferError(
      () => accept(wrongRecipient, otherUid),
      'permission-denied',
      'ownership-transfer-not-recipient',
    );

    const expired = new MemoryStore();
    seed(expired);
    await request(expired);
    const expiredDependencies = dependencies(expired);
    expiredDependencies.nowMillis = () => nowMillis + 48 * 60 * 60 * 1000;
    await expectTransferError(
      () => transferCompanyOwnershipForUser(
        targetUid,
        Math.floor(expiredDependencies.nowMillis() / 1000) - 60,
        { action: 'accept' },
        expiredDependencies,
      ),
      'failed-precondition',
      'ownership-transfer-expired',
    );

    const ownerDrift = new MemoryStore();
    seed(ownerDrift);
    await request(ownerDrift);
    ownerDrift.get(`memberDirectory/${ownerUid}`).role = 'admin';
    await expectTransferError(
      () => accept(ownerDrift),
      'failed-precondition',
      'ownership-transfer-state-invalid',
    );

    const targetLocked = new MemoryStore();
    seed(targetLocked);
    await request(targetLocked);
    targetLocked.set(`accountDeletionLocks/${targetUid}`, {});
    await expectTransferError(
      () => accept(targetLocked),
      'failed-precondition',
      'account-deletion-started',
    );
  });

  it('fails closed unless exactly one canonical company-name lock moves atomically', async () => {
    for (const nameLockResult of [
      [],
      [
        { path: 'companyNames/example', data: { companyId, createdBy: ownerUid } },
        { path: 'companyNames/duplicate', data: { companyId, createdBy: ownerUid } },
      ],
      [{
        path: 'companyNames/example',
        data: { companyId, createdBy: 'different-owner' },
      }],
      [{
        path: 'companyNames/example',
        data: { companyId, createdBy: ownerUid, extra: true },
      }],
    ]) {
      const store = new MemoryStore();
      seed(store);
      await request(store);
      store.nameLockResult = nameLockResult;
      await expectTransferError(
        () => accept(store),
        'failed-precondition',
        'ownership-transfer-state-invalid',
      );
      assert.equal(store.get(`companies/${companyId}`).createdBy, ownerUid);
      assert.equal(store.get(`users/${ownerUid}`).role, 'superadmin');
      assert.equal(store.get(`users/${targetUid}`).role, 'user');
    }
  });

  it('does not expose a partial transfer when the transaction commit fails', async () => {
    const store = new MemoryStore();
    seed(store);
    await request(store);
    store.failCommit = true;

    await assert.rejects(() => accept(store), /injected-commit-failure/);

    assert.equal(store.get(`companies/${companyId}`).createdBy, ownerUid);
    assert.equal(store.get('companyNames/example').createdBy, ownerUid);
    assert.equal(store.get(`users/${ownerUid}`).role, 'superadmin');
    assert.equal(store.get(`users/${targetUid}`).role, 'user');
    assert.equal(
      store.has(`companies/${companyId}/activity/${activityId}`),
      false,
    );
  });
});
