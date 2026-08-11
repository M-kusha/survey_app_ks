const assert = require('node:assert/strict');
const test = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const {
  ContentDeletionError,
  deleteContentForUser,
} = require('../lib/content_deletion');

const uid = 'staff_1';
const companyId = 'company_1';
const nowMillis = 1_700_000_000_000;

class MemoryStore {
  constructor() {
    this.documents = new Map();
    this.events = [];
    this.finalPaths = [];
  }

  set(path, data) { this.documents.set(path, { ...data }); }
  get(path) { return this.documents.get(path); }
  has(path) { return this.documents.has(path); }

  async runTransaction(operation) {
    const updates = [];
    const result = await operation({
      get: async (path) => this.get(path),
      update: (path, data) => updates.push({ path, data }),
    });
    for (const update of updates) {
      if (!this.has(update.path)) throw new Error(`not found: ${update.path}`);
      this.set(update.path, { ...this.get(update.path), ...update.data });
    }
    this.events.push('barrier');
    return result;
  }

  async deleteParticipants(parentPath, fail = false) {
    const prefix = `${parentPath}/participants/`;
    assert.equal(this.get(parentPath).deletionStartedAt instanceof Timestamp, true);
    this.events.push('children');
    if (fail) throw new Error('injected-child-delete-failure');
    for (const path of [...this.documents.keys()]) {
      if (path.startsWith(prefix)) this.documents.delete(path);
    }
  }

  async commitFinalDeletes(paths) {
    this.events.push('final');
    this.finalPaths = [...paths];
    for (const path of paths) this.documents.delete(path);
  }

  async participantsRemain(parentPath) {
    const prefix = `${parentPath}/participants/`;
    return [...this.documents.keys()].some((path) => path.startsWith(prefix));
  }
}

function seedStaff(store, overrides = {}) {
  store.set(`users/${uid}`, {
    companyId, role: 'admin', membership: 'active', ...overrides.profile,
  });
  store.set(`memberDirectory/${uid}`, {
    companyId, role: 'admin', membership: 'active', ...overrides.member,
  });
  store.set(`companies/${companyId}`, {
    name: 'Company', ...overrides.company,
  });
  if (overrides.ban) store.set(`companies/${companyId}/bans/${uid}`, {});
  if (overrides.accountLock) store.set(`accountDeletionLocks/${uid}`, {});
}

function dependencies(store, overrides = {}) {
  return {
    nowMillis: () => nowMillis,
    getAuthUser: async () => ({
      emailVerified: true, disabled: false, ...overrides.auth,
    }),
    runTransaction: store.runTransaction.bind(store),
    deleteParticipants: (path) =>
      store.deleteParticipants(path, overrides.failChildren === true),
    participantsRemain: store.participantsRemain.bind(store),
    commitFinalDeletes: store.commitFinalDeletes.bind(store),
  };
}

async function expectDeletionError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof ContentDeletionError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

test('barriers a survey before deleting children and finalizes its exact pair atomically', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  store.set('surveys/survey_1', { companyId });
  store.set('surveys/survey_1/participants/user_1', { userId: 'user_1' });
  store.set('surveyAnswerKeys/survey_1', { companyId });

  const result = await deleteContentForUser(
    uid,
    { entityType: 'survey', entityId: 'survey_1' },
    dependencies(store),
  );

  assert.deepEqual(result, {
    entityType: 'survey', entityId: 'survey_1', deleted: true,
  });
  assert.deepEqual(store.events, ['barrier', 'children', 'final']);
  assert.deepEqual(store.finalPaths, [
    'surveyAnswerKeys/survey_1',
    'surveys/survey_1',
  ]);
  assert.equal([...store.documents.keys()].some((path) => path.includes('survey_1')), false);
});

test('appointment cleanup removes votes and never targets a survey answer key', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  store.set('appointments/meeting_1', { companyId });
  store.set('appointments/meeting_1/participants/user_1-slot_1', { userId: 'user_1' });

  await deleteContentForUser(
    uid,
    { entityType: 'appointment', entityId: 'meeting_1' },
    dependencies(store),
  );
  assert.deepEqual(store.finalPaths, [
    'appointments/meeting_1',
  ]);
});

test('a child cleanup failure leaves the parent, key, and marker for an explicit retry', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  store.set('surveys/survey_1', { companyId });
  store.set('surveyAnswerKeys/survey_1', { companyId });

  await assert.rejects(
    deleteContentForUser(
      uid,
      { entityType: 'survey', entityId: 'survey_1' },
      dependencies(store, { failChildren: true }),
    ),
    /injected-child-delete-failure/,
  );
  assert.equal(store.has('surveys/survey_1'), true);
  assert.equal(store.has('surveyAnswerKeys/survey_1'), true);
  assert.equal(
    store.get('surveys/survey_1').deletionStartedAt instanceof Timestamp,
    true,
  );
  assert.deepEqual(store.events, ['barrier', 'children']);

  await deleteContentForUser(
    uid,
    { entityType: 'survey', entityId: 'survey_1' },
    dependencies(store),
  );
  assert.deepEqual(store.events, ['barrier', 'children', 'barrier', 'children', 'final']);
});

test('an invalid existing deletion marker fails closed', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  store.set('surveys/survey_1', { companyId, deletionStartedAt: 'forged' });
  await expectDeletionError(
    () => deleteContentForUser(
      uid,
      { entityType: 'survey', entityId: 'survey_1' },
      dependencies(store),
    ),
    'failed-precondition',
    'content-delete-state-invalid',
  );
});

test('the final parent delete is withheld when the zero-child check fails', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  store.set('appointments/meeting_1', { companyId });
  const deps = dependencies(store);
  deps.participantsRemain = async () => true;
  await assert.rejects(
    deleteContentForUser(
      uid,
      { entityType: 'appointment', entityId: 'meeting_1' },
      deps,
    ),
    /descendants remain/,
  );
  assert.equal(store.has('appointments/meeting_1'), true);
  assert.deepEqual(store.events, ['barrier', 'children']);
});

test('malformed, missing, cross-company, inactive, banned, and unavailable callers fail', async (t) => {
  const cases = [
    {
      name: 'malformed request', request: { entityType: 'survey', entityId: '../bad' },
      code: 'invalid-argument', message: 'content-delete-request-invalid',
    },
    {
      name: 'missing target', omitTarget: true,
      code: 'not-found', message: 'content-not-found',
    },
    {
      name: 'cross company', profile: { companyId: 'other' },
      code: 'permission-denied', message: 'content-delete-membership-required',
    },
    {
      name: 'ordinary member', profile: { role: 'user' }, member: { role: 'user' },
      code: 'permission-denied', message: 'content-delete-role-required',
    },
    {
      name: 'inactive member', profile: { membership: 'pending' }, member: { membership: 'pending' },
      code: 'permission-denied', message: 'content-delete-membership-required',
    },
    {
      name: 'banned member', ban: true,
      code: 'permission-denied', message: 'content-delete-banned',
    },
    {
      name: 'account deleting', accountLock: true,
      code: 'failed-precondition', message: 'content-delete-account-unavailable',
    },
    {
      name: 'disabled Auth', auth: { disabled: true },
      code: 'failed-precondition', message: 'content-delete-account-unavailable',
    },
  ];

  for (const entry of cases) {
    await t.test(entry.name, async () => {
      const store = new MemoryStore();
      seedStaff(store, entry);
      if (!entry.omitTarget) store.set('surveys/survey_1', { companyId });
      await expectDeletionError(
        () => deleteContentForUser(
          uid,
          entry.request ?? { entityType: 'survey', entityId: 'survey_1' },
          dependencies(store, { auth: entry.auth }),
        ),
        entry.code,
        entry.message,
      );
    });
  }
});

test('scheduled company cleanup does not block an otherwise authorized deletion', async () => {
  const store = new MemoryStore();
  seedStaff(store, { company: { deletionScheduledFor: new Date() } });
  store.set('appointments/meeting_1', { companyId });
  await deleteContentForUser(
    uid,
    { entityType: 'appointment', entityId: 'meeting_1' },
    dependencies(store),
  );
  assert.deepEqual(store.events, ['barrier', 'children', 'final']);
});
