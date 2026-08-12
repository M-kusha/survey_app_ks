const assert = require('node:assert/strict');
const test = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const {
  SurveyPublicationError,
  saveSurveyDefinitionForUser,
} = require('../lib/survey_publication');

const uid = 'staff_1';
const companyId = 'company_1';
const nowMillis = 1_700_000_000_000;

function copy(value) {
  if (Array.isArray(value)) return value.map(copy);
  if (value && typeof value === 'object' && Object.getPrototypeOf(value) === Object.prototype) {
    return Object.fromEntries(Object.entries(value).map(([key, entry]) => [key, copy(entry)]));
  }
  return value;
}

class MemoryStore {
  constructor({ failCommit = false } = {}) {
    this.documents = new Map();
    this.failCommit = failCommit;
  }

  set(path, data) { this.documents.set(path, copy(data)); }
  get(path) { return copy(this.documents.get(path)); }
  async runTransaction(operation) {
    const writes = [];
    const transaction = {
      get: async (path) => this.get(path),
      create: (path, data) => writes.push({ kind: 'create', path, data: copy(data) }),
    };
    const result = await operation(transaction);
    if (this.failCommit) throw new Error('injected-commit-failure');
    const next = new Map([...this.documents].map(([path, data]) => [path, copy(data)]));
    for (const write of writes) {
      if (write.kind === 'create') {
        if (next.has(write.path)) throw new Error(`already exists: ${write.path}`);
        next.set(write.path, write.data);
      }
    }
    this.documents = next;
    return result;
  }
}

function seedStaff(store, overrides = {}) {
  store.set(`users/${uid}`, {
    fullName: 'Staff', companyId, role: 'admin', membership: 'active',
    ...overrides.profile,
  });
  store.set(`memberDirectory/${uid}`, {
    fullName: 'Staff', companyId, role: 'admin', membership: 'active',
    ...overrides.member,
  });
  store.set(`companies/${companyId}`, {
    name: 'Company', createdBy: 'owner', joinPolicy: 'open',
    ...overrides.company,
  });
  if (overrides.lock) store.set(`accountDeletionLocks/${uid}`, { state: 'locked' });
  if (overrides.ban) store.set(`companies/${companyId}/bans/${uid}`, { banned: true });
}

function definition(overrides = {}) {
  return {
    surveyName: 'Canonical test',
    surveyDescription: 'No public grading keys',
    deadlineMillis: 2_000_000_000_000,
    timeLimitPerQuestion: 30,
    surveyType: 1,
    questions: [
      { type: 'Single', question: 'Pick', options: ['A', 'B'], correctAnswer: 1 },
      { type: 'Text', question: 'Explain' },
    ],
    ...overrides,
  };
}

function createRequest(overrides = {}) {
  return { action: 'create', surveyId: 'survey_1', definition: definition(), ...overrides };
}

function dependencies(store, auth = {}) {
  return {
    runTransaction: store.runTransaction.bind(store),
    nowMillis: () => nowMillis,
    getAuthUser: async () => ({ emailVerified: true, disabled: false, ...auth }),
  };
}

async function expectPublicationError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof SurveyPublicationError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

async function createPublished(store) {
  return saveSurveyDefinitionForUser(uid, createRequest(), dependencies(store));
}

test('creates only the exact canonical public/private pair in one transaction', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  assert.deepEqual(await createPublished(store), { surveyId: 'survey_1' });
  const survey = store.get('surveys/survey_1');
  const key = store.get('surveyAnswerKeys/survey_1');
  assert.deepEqual(Object.keys(survey).sort(), [
    'companyId', 'createdBy', 'deadline', 'id', 'participants', 'questions',
    'responsesRevision', 'surveyDescription', 'surveyName', 'surveyType',
    'timeCreated', 'timeLimitPerQuestion',
  ]);
  assert.deepEqual(Object.keys(key).sort(), [
    'companyId', 'questionKeys', 'schemaVersion', 'surveyId',
  ]);
  assert.equal(key.schemaVersion, 1);
  assert.equal(JSON.stringify(survey).includes('correctAnswer'), false);
  assert.deepEqual(key.questionKeys[0], { type: 'Single', correctAnswer: 1 });
  assert.deepEqual(
    store.get(`companies/${companyId}/activity/survey-created-survey_1`),
    {
      schemaVersion: 1,
      companyId,
      action: 'survey.created',
      actorUid: uid,
      entity: { type: 'test', id: 'survey_1', title: 'Canonical test' },
      occurredAt: Timestamp.fromMillis(nowMillis),
    },
  );
});

test('rejects unknown fields and invalid definitions', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await expectPublicationError(
    () => saveSurveyDefinitionForUser(uid, createRequest({ unexpected: true }), dependencies(store)),
    'invalid-argument', 'survey-request-invalid',
  );
  const invalid = createRequest();
  invalid.definition.questions[0].correctAnswer = 9;
  await expectPublicationError(
    () => saveSurveyDefinitionForUser(uid, invalid, dependencies(store)),
    'invalid-argument', 'survey-definition-invalid',
  );
});

test('a failed transaction leaves neither authoritative document', async () => {
  const store = new MemoryStore({ failCommit: true });
  seedStaff(store);
  await assert.rejects(() => createPublished(store), /injected-commit-failure/);
  assert.equal(store.get('surveys/survey_1'), undefined);
  assert.equal(store.get('surveyAnswerKeys/survey_1'), undefined);
  assert.equal(
    store.get(`companies/${companyId}/activity/survey-created-survey_1`),
    undefined,
  );
});

test('rechecks Auth, deletion, company, ban, membership and staff role', async () => {
  for (const [configure, auth, code, message] of [
    [(store) => seedStaff(store), { emailVerified: false }, 'failed-precondition', 'survey-author-account-unavailable'],
    [(store) => seedStaff(store), { disabled: true }, 'failed-precondition', 'survey-author-account-unavailable'],
    [(store) => {}, {}, 'failed-precondition', 'survey-author-account-unavailable'],
    [(store) => seedStaff(store, { lock: true }), {}, 'failed-precondition', 'survey-author-account-unavailable'],
    [(store) => seedStaff(store, { member: { companyId: 'other' } }), {}, 'failed-precondition', 'survey-author-membership-unavailable'],
    [(store) => seedStaff(store, { company: { deletionScheduledFor: true } }), {}, 'failed-precondition', 'company-closing'],
    [(store) => seedStaff(store, { ban: true }), {}, 'permission-denied', 'company-banned'],
    [(store) => seedStaff(store, { profile: { membership: 'pending' }, member: { membership: 'pending' } }), {}, 'permission-denied', 'company-membership-inactive'],
    [(store) => seedStaff(store, { profile: { role: 'user' }, member: { role: 'user' } }), {}, 'permission-denied', 'survey-author-role-required'],
  ]) {
    const store = new MemoryStore();
    configure(store);
    await expectPublicationError(
      () => saveSurveyDefinitionForUser(uid, createRequest(), dependencies(store, auth)),
      code, message,
    );
  }
});

test('never retries, repairs partial state, or overwrites an existing id', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await createPublished(store);
  await expectPublicationError(
    () => createPublished(store),
    'already-exists', 'survey-id-conflict',
  );

  const partial = new MemoryStore();
  seedStaff(partial);
  partial.set('surveyAnswerKeys/survey_1', { existing: true });
  await expectPublicationError(
    () => createPublished(partial),
    'already-exists', 'survey-id-conflict',
  );
});
