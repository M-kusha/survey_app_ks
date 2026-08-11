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
    this.collectionReads = [];
  }

  set(path, data) { this.documents.set(path, copy(data)); }
  get(path) { return copy(this.documents.get(path)); }
  async runTransaction(operation) {
    const writes = [];
    const transaction = {
      get: async (path) => this.get(path),
      list: async (path) => {
        this.collectionReads.push(path);
        const prefix = `${path}/`;
        return [...this.documents]
          .filter(([documentPath]) =>
            documentPath.startsWith(prefix) && !documentPath.slice(prefix.length).includes('/'))
          .map(([, data]) => copy(data));
      },
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

class ConcurrentVoteStore extends MemoryStore {
  constructor() {
    super();
    this.concurrentVote = undefined;
    this.transactionAttempts = 0;
  }

  armVoteBeforeNextCommit(path, vote) {
    this.concurrentVote = { path, vote: copy(vote) };
    this.transactionAttempts = 0;
  }

  async runTransaction(operation) {
    this.transactionAttempts += 1;
    const snapshot = new Map(
      [...this.documents].map(([path, data]) => [path, copy(data)]),
    );
    const writes = [];
    const transaction = {
      get: async (path) => copy(snapshot.get(path)),
      list: async (path) => {
        this.collectionReads.push(path);
        const prefix = `${path}/`;
        return [...snapshot]
          .filter(([documentPath]) =>
            documentPath.startsWith(prefix) &&
            !documentPath.slice(prefix.length).includes('/'))
          .map(([, data]) => copy(data));
      },
      create: (path, data) =>
        writes.push({ kind: 'create', path, data: copy(data) }),
      set: (path, data) =>
        writes.push({ kind: 'set', path, data: copy(data) }),
    };
    const result = await operation(transaction);

    if (this.concurrentVote) {
      const { path, vote } = this.concurrentVote;
      this.concurrentVote = undefined;
      this.set(path, vote);
      return this.runTransaction(operation);
    }

    for (const write of writes) {
      if (write.kind === 'create' && this.documents.has(write.path)) {
        throw new Error(`already exists: ${write.path}`);
      }
      this.set(write.path, write.data);
    }
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

async function expectDefinitionError(operation, code, message, details) {
  await assert.rejects(operation, (error) => {
    assert.equal(error instanceof AppointmentDefinitionError, true);
    assert.equal(error.code, code);
    assert.equal(error.message, message);
    assert.deepEqual(error.details, details);
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
  assert.deepEqual(store.collectionReads, []);

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

test('allows unvoted removal and ignores votes on retained slots', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await createAppointment(store);
  store.set(`appointments/${appointmentId}/participants/vote_late`, {
    userId: 'voter_1', userName: 'Voter', slotId: 'slot_late',
    status: 'joined', participated: true,
  });
  const onlyLate = definition({ slots: [definition().slots[0]] });

  assert.deepEqual(await saveAppointmentDefinitionForUser(
    uid, updateRequest(1, { definition: onlyLate }), dependencies(store),
  ), { appointmentId, revision: 2 });
  assert.deepEqual(store.get(`appointments/${appointmentId}`).slotIds, ['slot_late']);
  assert.deepEqual(store.collectionReads, [`appointments/${appointmentId}/participants`]);
});

test('a simple input reorder retains every slot without reading votes', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  await createAppointment(store);
  store.collectionReads.length = 0;

  const chronological = [...definition().slots].reverse();
  assert.deepEqual(chronological.map((slot) => slot.slotId), [
    'slot_early', 'slot_late',
  ]);
  assert.deepEqual(await saveAppointmentDefinitionForUser(
    uid,
    updateRequest(1, { definition: definition({ slots: chronological }) }),
    dependencies(store),
  ), { appointmentId, revision: 2 });
  assert.deepEqual(store.get(`appointments/${appointmentId}`).slotIds, [
    'slot_early', 'slot_late',
  ]);
  assert.deepEqual(store.collectionReads, []);
});

test('a concurrent vote commits first, retries the edit, and blocks its slot removal', async () => {
  const store = new ConcurrentVoteStore();
  seedStaff(store);
  await createAppointment(store);
  const appointmentPath = `appointments/${appointmentId}`;
  store.collectionReads.length = 0;
  store.armVoteBeforeNextCommit(`${appointmentPath}/participants/racing_vote`, {
    userId: 'racing_voter', userName: 'Racing voter', slotId: 'slot_early',
    status: 'joined', participated: true,
  });
  const onlyLate = definition({ slots: [definition().slots[0]] });

  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(
      uid, updateRequest(1, { definition: onlyLate }), dependencies(store),
    ),
    'failed-precondition', 'appointment-voted-slot-removal-blocked',
    { blockedSlotIds: ['slot_early'] },
  );
  assert.equal(store.transactionAttempts, 2);
  assert.deepEqual(store.collectionReads, [
    `${appointmentPath}/participants`,
    `${appointmentPath}/participants`,
  ]);
  assert.equal(store.get(appointmentPath).revision, 1);
  assert.equal(
    store.get(`${appointmentPath}/participants/racing_vote`).slotId,
    'slot_early',
  );
});

test('blocks voted removals with sorted ids after revision validation', async () => {
  const store = new MemoryStore();
  seedStaff(store);
  const slots = [
    { slotId: 'slot_z', startAtMillis: nowMillis + 120_000, endAtMillis: nowMillis + 180_000 },
    { slotId: 'slot_a', startAtMillis: nowMillis + 240_000, endAtMillis: nowMillis + 300_000 },
    { slotId: 'slot_keep', startAtMillis: nowMillis + 360_000, endAtMillis: nowMillis + 420_000 },
  ];
  await createAppointment(store, createRequest({ definition: definition({ slots }) }));
  const path = `appointments/${appointmentId}`;
  const appointment = store.get(path);
  appointment.revision = 2;
  store.set(path, appointment);
  for (const [documentId, slotId] of [['vote_z', 'slot_z'], ['vote_a', 'slot_a']]) {
    store.set(`${path}/participants/${documentId}`, {
      userId: documentId, userName: 'Voter', slotId, status: 'joined', participated: true,
    });
  }
  const keepOnly = definition({ slots: [slots[2]] });

  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(
      uid, updateRequest(1, { definition: keepOnly }), dependencies(store),
    ),
    'aborted', 'appointment-revision-conflict',
  );
  assert.deepEqual(store.collectionReads, []);

  await expectDefinitionError(
    () => saveAppointmentDefinitionForUser(
      uid, updateRequest(2, { definition: keepOnly }), dependencies(store),
    ),
    'failed-precondition', 'appointment-voted-slot-removal-blocked',
    { blockedSlotIds: ['slot_a', 'slot_z'] },
  );
  assert.deepEqual(store.collectionReads, [`${path}/participants`]);
  assert.equal(store.get(path).revision, 2);
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
