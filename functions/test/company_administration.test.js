const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const {
  CompanyAdministrationError,
  administerCompanyForUser,
} = require('../lib/company_administration');
const { writeCompanyActivity } = require('../lib/activity_log');

const ownerUid = 'owner-1';
const targetUid = 'member-1';
const companyId = 'company-1';
const nowMillis = 1_700_000_000_000;
const recentAuthTime = Math.floor(nowMillis / 1000) - 60;

class MemoryStore {
  constructor() {
    this.documents = new Map();
    this.transactionCalls = 0;
    this.failOnTransactionCall = null;
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

  delete(path) {
    this.documents.delete(path);
  }

  async runTransaction(operation) {
    this.transactionCalls += 1;
    const writes = [];
    const result = await operation({
      get: async (path) => this.get(path),
      create: (path, data) => writes.push({ type: 'create', path, data }),
      update: (path, data) => writes.push({ type: 'update', path, data }),
      delete: (path) => writes.push({ type: 'delete', path }),
    });
    if (this.transactionCalls === this.failOnTransactionCall) {
      throw new Error('injected-transaction-failure');
    }
    for (const write of writes) {
      if (write.type === 'create') {
        if (this.has(write.path)) throw new Error(`already exists: ${write.path}`);
        this.set(write.path, write.data);
      } else if (write.type === 'update') {
        if (!this.has(write.path)) throw new Error(`not found: ${write.path}`);
        const next = { ...this.get(write.path) };
        for (const [key, value] of Object.entries(write.data)) {
          if (typeof value === 'symbol') delete next[key];
          else next[key] = value;
        }
        this.set(write.path, next);
      } else {
        this.delete(write.path);
      }
    }
    return result;
  }

  activities() {
    return [...this.documents.entries()]
      .filter(([path]) => path.startsWith(`companies/${companyId}/activity/`))
      .map(([path, data]) => ({ id: path.split('/').at(-1), data }));
  }
}

function seed(store, target = {}) {
  store.set(`users/${ownerUid}`, {
    fullName: 'Owner One',
    companyId,
    role: 'superadmin',
    membership: 'active',
  });
  store.set(`memberDirectory/${ownerUid}`, {
    fullName: 'Owner One',
    companyId,
    role: 'superadmin',
    membership: 'active',
  });
  store.set(`companies/${companyId}`, {
    name: 'Example',
    createdBy: ownerUid,
    joinPolicy: 'open',
  });
  store.set(`companyDirectory/${companyId}`, {
    name: 'Example',
    joinPolicy: 'open',
  });
  store.set(`users/${targetUid}`, {
    fullName: 'Member One',
    companyId,
    role: 'user',
    membership: 'active',
    ...target,
  });
  store.set(`memberDirectory/${targetUid}`, {
    fullName: 'Member One',
    companyId,
    role: 'user',
    membership: 'active',
    ...target,
  });
}

function dependencies(store, options = {}) {
  let nextId = 0;
  return {
    getAuthUser: async (uid) => ({
      emailVerified: true,
      disabled: false,
      ...(options.authByUid?.[uid] ?? {}),
    }),
    runTransaction: store.runTransaction.bind(store),
    listCompanyParticipantPaths:
      options.listCompanyParticipantPaths ?? (async () => []),
    newActivityId: () => `activity-${++nextId}`,
    nowMillis: () => nowMillis,
    serverTimestamp: () => 'server-time',
  };
}

async function expectAdministrationError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof CompanyAdministrationError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

describe('trusted company administration and activity', () => {
  it('approves a pending member and appends the exact PII-free event atomically', async () => {
    const store = new MemoryStore();
    seed(store, { membership: 'pending' });

    const result = await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'approveMember', targetUid },
      dependencies(store),
    );

    assert.deepEqual(result, {
      completed: true,
      action: 'approveMember',
      activityId: 'activity-1',
      companyId,
      targetUid,
      membership: 'active',
    });
    assert.equal(store.get(`users/${targetUid}`).membership, 'active');
    assert.equal(store.get(`memberDirectory/${targetUid}`).membership, 'active');
    assert.deepEqual(store.activities(), [{
      id: 'activity-1',
      data: {
        schemaVersion: 1,
        companyId,
        action: 'member.approved',
        actorUid: ownerUid,
        targetUid,
        occurredAt: 'server-time',
        before: { membership: 'pending' },
        after: { membership: 'active' },
      },
    }]);

    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'approveMember', targetUid },
        dependencies(store),
      ),
      'failed-precondition',
      'member-already-active',
    );
    assert.equal(store.activities().length, 1);
  });

  it('rejects client-supplied tenant/state fields before any write', async () => {
    const store = new MemoryStore();
    seed(store, { membership: 'pending' });
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'approveMember', targetUid, companyId, before: {} },
        dependencies(store),
      ),
      'invalid-argument',
      'member-target-invalid',
    );
    assert.equal(store.activities().length, 0);
  });

  it('changes role only for a live verified Auth target and an exact projection', async () => {
    const store = new MemoryStore();
    seed(store);
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'changeMemberRole', targetUid, role: 'admin' },
        dependencies(store, { authByUid: { [targetUid]: { disabled: true } } }),
      ),
      'failed-precondition',
      'member-account-unavailable',
    );

    store.set(`users/${targetUid}`, {
      ...store.get(`users/${targetUid}`),
      profileImage: `profile_images/${targetUid}/avatar.jpg`,
      profileImageRevision: 2,
    });
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'changeMemberRole', targetUid, role: 'admin' },
        dependencies(store),
      ),
      'failed-precondition',
      'member-state-invalid',
    );

    store.set(`memberDirectory/${targetUid}`, {
      ...store.get(`memberDirectory/${targetUid}`),
      profileImage: `profile_images/${targetUid}/avatar.jpg`,
      profileImageRevision: 2,
    });
    const result = await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'changeMemberRole', targetUid, role: 'admin' },
      dependencies(store),
    );
    assert.equal(result.role, 'admin');
    assert.deepEqual(store.activities()[0].data.before, { role: 'user' });
    assert.deepEqual(store.activities()[0].data.after, { role: 'admin' });
  });

  it('bans and unbans using only server-derived target state', async () => {
    const store = new MemoryStore();
    seed(store);
    const deps = dependencies(store);

    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'banMember', targetUid },
      deps,
    );
    assert.deepEqual(store.get(`companies/${companyId}/bans/${targetUid}`), {
      name: 'Member One',
      bannedAt: 'server-time',
      bannedBy: ownerUid,
      previousMembership: 'active',
    });
    assert.equal(store.get(`users/${targetUid}`).membership, 'pending');

    const result = await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'unbanMember', targetUid },
      deps,
    );
    assert.equal(result.membership, 'active');
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), false);
    assert.equal(store.get(`memberDirectory/${targetUid}`).membership, 'active');
    assert.deepEqual(store.activities().map(({ data }) => data.action), [
      'member.banned',
      'member.unbanned',
    ]);
  });

  it('unbans a member who already self-left without recreating membership', async () => {
    const store = new MemoryStore();
    seed(store);
    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One',
      previousMembership: 'active',
    });
    store.set(`users/${targetUid}`, {
      ...store.get(`users/${targetUid}`),
      companyId: '',
      role: 'user',
      membership: 'active',
    });
    store.delete(`memberDirectory/${targetUid}`);

    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'unbanMember', targetUid },
      dependencies(store),
    );
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), false);
    assert.equal(store.has(`memberDirectory/${targetUid}`), false);
    assert.equal(store.get(`users/${targetUid}`).companyId, '');
    assert.equal('before' in store.activities()[0].data, false);
    assert.equal('after' in store.activities()[0].data, false);
  });

  it('clears an old-company ban without touching the target new company', async () => {
    const store = new MemoryStore();
    seed(store);
    const newCompanyId = 'company-2';
    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One',
      previousMembership: 'active',
    });
    store.set(`users/${targetUid}`, {
      ...store.get(`users/${targetUid}`),
      companyId: newCompanyId,
      role: 'superadmin',
      membership: 'active',
    });
    store.set(`memberDirectory/${targetUid}`, {
      ...store.get(`memberDirectory/${targetUid}`),
      companyId: newCompanyId,
      role: 'superadmin',
      membership: 'active',
    });

    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'unbanMember', targetUid },
      dependencies(store),
    );
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), false);
    assert.equal(store.get(`users/${targetUid}`).companyId, newCompanyId);
    assert.equal(store.get(`users/${targetUid}`).role, 'superadmin');
    assert.equal(store.get(`memberDirectory/${targetUid}`).companyId, newCompanyId);
  });

  it('does not mutate a detached ban while target account deletion is active', async () => {
    const store = new MemoryStore();
    seed(store);
    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One',
      previousMembership: 'active',
    });
    store.set(`users/${targetUid}`, {
      ...store.get(`users/${targetUid}`),
      companyId: '',
      role: 'user',
      membership: 'active',
    });
    store.delete(`memberDirectory/${targetUid}`);
    store.set(`accountDeletionLocks/${targetUid}`, { startedAt: 'server-time' });

    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'unbanMember', targetUid },
        dependencies(store),
      ),
      'failed-precondition',
      'member-account-deleting',
    );
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), true);
    assert.equal(store.activities().length, 0);
  });

  it('removes a normal member but refuses to strand a ban', async () => {
    const store = new MemoryStore();
    seed(store);
    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'removeMember', targetUid },
      dependencies(store),
    );
    assert.deepEqual(
      (({ companyId: id, role, membership }) => ({ companyId: id, role, membership }))(
        store.get(`users/${targetUid}`),
      ),
      { companyId: '', role: 'user', membership: 'active' },
    );
    assert.equal(store.has(`memberDirectory/${targetUid}`), false);

    const banned = new MemoryStore();
    seed(banned, { membership: 'pending' });
    banned.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One', previousMembership: 'active',
    });
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'removeMember', targetUid },
        dependencies(banned),
      ),
      'failed-precondition',
      'member-banned',
    );
  });

  it('requires a ban before erasing history and logs only after cleanup succeeds', async () => {
    const store = new MemoryStore();
    seed(store);
    let listingCalls = 0;
    const participantPath = `surveys/survey-1/participants/${targetUid}`;
    store.set(participantPath, { userId: targetUid });
    const deps = dependencies(store, {
      listCompanyParticipantPaths: async (seenCompany, seenTarget) => {
        assert.deepEqual([seenCompany, seenTarget], [companyId, targetUid]);
        listingCalls += 1;
        return [participantPath];
      },
    });
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'eraseMemberCompanyData', targetUid },
        deps,
      ),
      'failed-precondition',
      'member-not-banned',
    );
    assert.equal(listingCalls, 0);

    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One', previousMembership: 'active',
    });
    store.set(`users/${targetUid}`, {
      ...store.get(`users/${targetUid}`), membership: 'pending',
    });
    store.set(`memberDirectory/${targetUid}`, {
      ...store.get(`memberDirectory/${targetUid}`), membership: 'pending',
    });
    const result = await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'eraseMemberCompanyData', targetUid },
      deps,
    );
    assert.equal(result.released, true);
    assert.equal(listingCalls, 1);
    assert.equal(store.has(participantPath), false);
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), false);
    assert.equal(store.has(`memberDirectory/${targetUid}`), false);
    assert.equal(store.activities()[0].data.action, 'member.company_data_erased');
  });

  it('erases historical data for a banned member who already self-left', async () => {
    const store = new MemoryStore();
    seed(store);
    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One', previousMembership: 'active',
    });
    store.set(`users/${targetUid}`, {
      ...store.get(`users/${targetUid}`),
      companyId: '', role: 'user', membership: 'active',
    });
    store.delete(`memberDirectory/${targetUid}`);
    let listed = false;

    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'eraseMemberCompanyData', targetUid },
      dependencies(store, {
        listCompanyParticipantPaths: async () => {
          listed = true;
          return [];
        },
      }),
    );
    assert.equal(listed, true);
    assert.equal(store.get(`users/${targetUid}`).companyId, '');
    assert.equal(store.has(`memberDirectory/${targetUid}`), false);
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), false);
  });

  it('erases only old-company history after the target joins another company', async () => {
    const store = new MemoryStore();
    seed(store);
    const newCompanyId = 'company-2';
    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One',
      previousMembership: 'active',
    });
    for (const path of [`users/${targetUid}`, `memberDirectory/${targetUid}`]) {
      store.set(path, {
        ...store.get(path),
        companyId: newCompanyId,
        role: 'admin',
        membership: 'active',
      });
    }
    const oldVotePath = `appointments/old/participants/${targetUid}-slot`;
    store.set(oldVotePath, { userId: targetUid });

    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'eraseMemberCompanyData', targetUid },
      dependencies(store, {
        listCompanyParticipantPaths: async () => [oldVotePath],
      }),
    );
    assert.equal(store.has(oldVotePath), false);
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), false);
    assert.equal(store.get(`users/${targetUid}`).companyId, newCompanyId);
    assert.equal(store.get(`users/${targetUid}`).role, 'admin');
    assert.equal(store.get(`memberDirectory/${targetUid}`).companyId, newCompanyId);
  });

  it('keeps participant deletion, release, ban removal and activity atomic', async () => {
    const store = new MemoryStore();
    seed(store, { membership: 'pending' });
    store.set(`companies/${companyId}/bans/${targetUid}`, {
      name: 'Member One',
      previousMembership: 'active',
    });
    const participantPath = `surveys/survey-1/participants/${targetUid}`;
    store.set(participantPath, { userId: targetUid });
    store.failOnTransactionCall = 2;

    await assert.rejects(
      administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'eraseMemberCompanyData', targetUid },
        dependencies(store, {
          listCompanyParticipantPaths: async () => [participantPath],
        }),
      ),
      /injected-transaction-failure/,
    );
    assert.equal(store.has(participantPath), true);
    assert.equal(store.has(`companies/${companyId}/bans/${targetUid}`), true);
    assert.equal(store.has(`memberDirectory/${targetUid}`), true);
    assert.equal(store.get(`users/${targetUid}`).companyId, companyId);
    assert.equal(store.activities().length, 0);
  });

  it('changes join policy in both documents and rejects a no-op', async () => {
    const store = new MemoryStore();
    seed(store);
    await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'setJoinPolicy', joinPolicy: 'approval' },
      dependencies(store),
    );
    assert.equal(store.get(`companies/${companyId}`).joinPolicy, 'approval');
    assert.equal(store.get(`companyDirectory/${companyId}`).joinPolicy, 'approval');
    assert.equal(store.activities()[0].data.action, 'company.join_policy_changed');
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'setJoinPolicy', joinPolicy: 'approval' },
        dependencies(store),
      ),
      'failed-precondition',
      'join-policy-unchanged',
    );
  });

  it('requires owner recent-auth for scheduling and atomically logs cancellation', async () => {
    const store = new MemoryStore();
    seed(store);
    const deps = dependencies(store);
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime - 600,
        { action: 'scheduleDeletion' },
        deps,
      ),
      'failed-precondition',
      'recent-login-required',
    );

    const scheduled = await administerCompanyForUser(
      ownerUid,
      recentAuthTime,
      { action: 'scheduleDeletion' },
      deps,
    );
    assert.equal(
      scheduled.deletionScheduledForMillis,
      nowMillis + 7 * 24 * 60 * 60 * 1000,
    );
    assert.equal(
      store.get(`companies/${companyId}`).deletionScheduledFor.toMillis(),
      scheduled.deletionScheduledForMillis,
    );
    assert.equal(store.activities()[0].data.action, 'company.deletion_scheduled');

    const cancelled = await administerCompanyForUser(
      ownerUid,
      recentAuthTime - 600,
      { action: 'cancelDeletion' },
      deps,
    );
    assert.equal(cancelled.cancelled, true);
    assert.equal('deletionScheduledFor' in store.get(`companies/${companyId}`), false);
    assert.equal('deletionRequestedBy' in store.get(`companies/${companyId}`), false);
    assert.equal(store.activities()[1].data.action, 'company.deletion_cancelled');

    const claimed = new MemoryStore();
    seed(claimed);
    claimed.set(`companies/${companyId}`, {
      ...claimed.get(`companies/${companyId}`),
      deletionScheduledFor: Timestamp.fromMillis(nowMillis),
      deletionRequestedBy: ownerUid,
      purgeStartedAt: Timestamp.fromMillis(nowMillis),
    });
    await expectAdministrationError(
      () => administerCompanyForUser(
        ownerUid,
        recentAuthTime,
        { action: 'cancelDeletion' },
        dependencies(claimed),
      ),
      'failed-precondition',
      'company-purge-started',
    );
    assert.equal(claimed.activities().length, 0);
  });

  it('the shared activity writer rejects PII even from trusted feature code', () => {
    assert.throws(
      () => writeCompanyActivity(
        { create: () => assert.fail('unsafe event must not be written') },
        {
          id: 'unsafe',
          companyId,
          action: 'account.email_changed',
          actorUid: ownerUid,
          occurredAt: 'server-time',
          before: { email: 'secret@example.com' },
        },
      ),
      /forbidden field/,
    );
  });
});
