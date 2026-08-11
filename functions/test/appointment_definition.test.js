const assert = require('node:assert/strict');
const test = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const {
  AppointmentDefinitionError,
  saveAppointmentDefinitionForUser,
} = require('../lib/appointment_definition');

const uid = 'staff_1';
const companyId = 'company_1';
const appointmentId = 'appointment_1';
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
      set: (path, data) => writes.push({ kind: 'set', path, data: copy(data) }),
    };
    const result = await operation(transaction);
    if (this.failCommit) throw new Error('injected-commit-failure');
    const next = new Map([...this.documents].map(([path, data]) => [path, copy(data)]));
    for (const write of writes) {
      if (write.kind === 'create' && next.has(write.path)) {
        throw new Error(`already exists: ${write.path}`);
      }
      next.set(write.path, write.data);
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
  store.set(`companies/${companyId}`, { name: 'Company', ...overrides.company });
  if (overrides.lock) store.set(`accountDeletionLocks/${uid}`, { state: 'locked' });
  if (overrides.ban) store.set(`companies/${companyId}/bans/${uid}`, { banned: true });
}

function definition(overrides = {}) {
  return {
    title: 'Planning',
    description: 'Choose a time',
    zoneId: 'Europe/Berlin',
    expirationAtMillis: nowMillis + 60_000,
    slots: [
      { slotId: 'slot_late', startAtMillis: nowMillis + 240_000, endAtMillis: nowMillis + 300_000 },
      { slotId: 'slot_early', startAtMillis: nowMillis + 120_000, endAtMillis: nowMillis + 180_000 },
    ],
    ...overrides,
  };
}

function createRequest(overrides = {}) {
  return { action: 'create', appointmentId, definition: definition(), ...overrides };
}

function updateRequest(expectedRevision, overrides = {}) {
  return {
    action: 'update', appointmentId, expectedRevision, reopenVoting: false,
    definition: definition(), ...overrides,
  };
}

function dependencies(store, overrides = {}) {
  return {
    runTransaction: store.runTransaction.bind(store),
    nowMillis: () => overrides.nowMillis ?? nowMillis,
    getAuthUser: async () => ({
      emailVerified: true,
      disabled: false,
      ...overrides.auth,
    }),
  };
}

async function expectDefinitionError(operation, code, message) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof AppointmentDefinitionError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    return true;
  });
}

async function createAppointment(store, request = createRequest()) {
  return saveAppointmentDefinitionForUser(uid, request, dependencies(store));
}

test('creates the exact canonical v2 Timestamp document sorted by instant', async () => {
  const store = new MemoryStore();
  seedStaff(store);

  assert.deepEqual(await createAppointment(store), { appointmentId, revision: 1 });
  const appointment = store.get(`appointments/${appointmentId}`);
  assert.deepEqual(Object.keys(appointment).sort(), [
    'appointmentId', 'companyId', 'confirmedSlotId', 'createdAt', 'createdBy',
    'description', 'expirationAt', 'participantUserIds', 'revision',
    'schemaVersion', 'slotIds', 'slots', 'title', 'zoneId',
  ]);
  assert.equal(appointment.schemaVersion, 2);
  assert.equal(appointment.revision, 1);
  assert.deepEqual(appointment.slotIds, ['slot_early', 'slot_late']);
  assert.deepEqual(appointment.slots.map((slot) => slot.slotId), appointment.slotIds);
  assert.ok(appointment.createdAt instanceof Timestamp);
  assert.ok(appointment.expirationAt instanceof Timestamp);
  assert.ok(appointment.slots.every((slot) =>
    slot.startAt instanceof Timestamp && slot.endAt instanceof Timestamp));
  assert.equal(appointment.expirationAt.toMillis(), nowMillis + 60_000);
  assert.equal(appointment.confirmedSlotId, null);
  assert.deepEqual(appointment.participantUserIds, []);
  assert.equal('expirationDate' in appointment, false);
  assert.equal(JSON.stringify(appointment).includes('T00:'), false);
});

test('enforces strict server now < expirationAt < earliest startAt boundaries', async () => {
  for (const [expirationAtMillis, firstStartAtMillis, accepted] of [
    [nowMillis, nowMillis + 2, false],
    [nowMillis + 1, nowMillis + 1, false],
    [nowMillis + 1, nowMillis + 2, true],
  ]) {
    const store = new MemoryStore();
    seedStaff(store);
    const request = createRequest({
      definition: definition({
        expirationAtMillis,
        slots: [{
          slotId: 'boundary', startAtMillis: firstStartAtMillis,
          endAtMillis: firstStartAtMillis + 1,
        }],
      }),
    });
    if (accepted) {
      assert.deepEqual(await createAppointment(store, request), { appointmentId, revision: 1 });
    } else {
      await expectDefinitionError(
        () => createAppointment(store, request),
        'invalid-argument', 'appointment-deadline-invalid',
      );
    }
  }
});

test('rejects offset-less strings, invalid zones, duplicate ids and unknown fields', async () => {
  const cases = [];
  const stringInstant = createRequest();
  stringInstant.definition.slots[0].startAtMillis = '2026-10-25T02:30:00';
  cases.push(stringInstant);
  cases.push(createRequest({ definition: definition({ zoneId: 'Mars/Olympus' }) }));
  cases.push(createRequest({ definition: definition({ description: '   ' }) }));
  cases.push(createRequest({
    definition: definition({
      slots: [
        { slotId: 'same', startAtMillis: nowMillis + 120_000, endAtMillis: nowMillis + 180_000 },
        { slotId: 'same', startAtMillis: nowMillis + 240_000, endAtMillis: nowMillis + 300_000 },
      ],
    }),
  }));
  cases.push({ ...createRequest(), unexpected: true });

  for (const request of cases) {
    const store = new MemoryStore();
    seedStaff(store);
    await expectDefinitionError(
      () => createAppointment(store, request),
      'invalid-argument', 'appointment-request-invalid',
    );
  }
});

test('rechecks Auth, deletion state, company, ban, membership and staff role', async () => {
  for (const [configure, auth, code, message] of [
    [(store) => seedStaff(store), { emailVerified: false }, 'failed-precondition', 'appointment-author-account-unavailable'],
    [(store) => seedStaff(store), { disabled: true }, 'failed-precondition', 'appointment-author-account-unavailable'],
    [() => {}, {}, 'failed-precondition', 'appointment-author-account-unavailable'],
    [(store) => seedStaff(store, { lock: true }), {}, 'failed-precondition', 'appointment-author-account-unavailable'],
    [(store) => seedStaff(store, { member: { companyId: 'other' } }), {}, 'failed-precondition', 'appointment-author-membership-unavailable'],
    [(store) => seedStaff(store, { company: { deletionScheduledFor: Timestamp.now() } }), {}, 'failed-precondition', 'company-closing'],
    [(store) => seedStaff(store, { ban: true }), {}, 'permission-denied', 'company-banned'],
    [(store) => seedStaff(store, { profile: { membership: 'pending' }, member: { membership: 'pending' } }), {}, 'permission-denied', 'company-membership-inactive'],
    [(store) => seedStaff(store, { profile: { role: 'user' }, member: { role: 'user' } }), {}, 'permission-denied', 'appointment-author-role-required'],
  ]) {
    const store = new MemoryStore();
    configure(store);
    await expectDefinitionError(
      () => saveAppointmentDefinitionForUser(
        uid, createRequest(), dependencies(store, { auth }),
      ),
      code, message,
    );
  }
});

test('update is revision-safe, preserves identity and rejects retained slot retiming', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await createAppointment(store);
  const path = `appointments/${appointmentId}`;
  const confirmed = store.get(path);
  confirmed.revision = 2;
  confirmed.confirmedSlotId = 'slot_early';
  confirmed.participantUserIds = ['voter_1'];
  store.set(path, confirmed);

  assert.deepEqual(await saveAppointmentDefinitionForUser(
    uid,
    updateRequest(2, { definition: definition({ title: 'Edited planning' }) }),
    dependencies(store),
  ), { appointmentId, revision: 3 });
  const edited = store.get(path);
  assert.equal(edited.title, 'Edited planning');
  assert.equal(edited.createdBy, uid);
  assert.equal(edited.createdAt.toMillis(), nowMillis);
  assert.equal(edited.confirmedSlotId, 'slot_early');
  assert.deepEqual(edited.participantUserIds, ['voter_1']);

  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(uid, updateRequest(2), dependencies(store)),
    'aborted', 'appointment-revision-conflict',
  );

  const retimed = definition();
  retimed.slots[1].startAtMillis += 1;
  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(
      uid, updateRequest(3, { definition: retimed }), dependencies(store),
    ),
    'invalid-argument', 'appointment-slot-id-reused',
  );
});

test('active staff cannot update an appointment owned by another tenant', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await createAppointment(store);
  store.set(`users/${uid}`, {
    fullName: 'Staff', companyId: 'company_2', role: 'admin', membership: 'active',
  });
  store.set(`memberDirectory/${uid}`, {
    fullName: 'Staff', companyId: 'company_2', role: 'admin', membership: 'active',
  });
  store.set('companies/company_2', { name: 'Other company' });

  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(
      uid, updateRequest(1), dependencies(store),
    ),
    'permission-denied', 'appointment-company-mismatch',
  );
  assert.equal(store.get(`appointments/${appointmentId}`).revision, 1);
});

test('confirmed slot removal requires explicit reopening and clears it atomically', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await createAppointment(store);
  const path = `appointments/${appointmentId}`;
  const confirmed = store.get(path);
  confirmed.revision = 2;
  confirmed.confirmedSlotId = 'slot_early';
  store.set(path, confirmed);
  const onlyLate = definition({ slots: [definition().slots[0]] });

  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(
      uid, updateRequest(2, { definition: onlyLate }), dependencies(store),
    ),
    'failed-precondition', 'appointment-confirmed-slot-removed',
  );
  assert.equal(store.get(path).confirmedSlotId, 'slot_early');

  assert.deepEqual(await saveAppointmentDefinitionForUser(
    uid,
    updateRequest(2, { reopenVoting: true, definition: onlyLate }),
    dependencies(store),
  ), { appointmentId, revision: 3 });
  assert.equal(store.get(path).confirmedSlotId, null);
  assert.deepEqual(store.get(path).slotIds, ['slot_late']);
});

test('failed create transaction leaves no appointment document', async () => {
  const store = new MemoryStore({ failCommit: true });
  seedStaff(store);
  await assert.rejects(() => createAppointment(store), /injected-commit-failure/);
  assert.equal(store.get(`appointments/${appointmentId}`), undefined);
});
