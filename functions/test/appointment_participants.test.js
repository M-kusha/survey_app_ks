const assert = require('node:assert/strict');
const { after, beforeEach, describe, it, mock } = require('node:test');

const firestoreAdmin = require('firebase-admin/firestore');

let activeStore;
mock.method(firestoreAdmin, 'getFirestore', () => activeStore);
after(() => mock.restoreAll());

const {
  registerAppointmentParticipant,
} = require('../lib/appointment_participants');

function snapshot(data) {
  return {
    exists: data !== undefined,
    get: (field) => data?.[field],
  };
}

function participantStore({ parent = {}, vote, lock } = {}) {
  const documents = new Map([
    ['appointments/appointment-1', parent],
  ]);
  if (vote !== undefined) {
    documents.set('appointments/appointment-1/participants/vote-1', vote);
  }
  if (lock !== undefined) {
    documents.set('accountDeletionLocks/user-1', lock);
  }
  const updates = [];
  const reference = (path) => ({
    path,
    collection: (name) => ({
      doc: (id) => reference(`${path}/${name}/${id}`),
    }),
  });
  return {
    updates,
    collection: (name) => ({
      doc: (id) => reference(`${name}/${id}`),
    }),
    runTransaction: async (operation) => operation({
      getAll: async (...references) =>
        references.map((ref) => snapshot(documents.get(ref.path))),
      update: (ref, values) => updates.push([ref.path, values]),
    }),
  };
}

describe('trusted appointment participant cache', () => {
  beforeEach(() => {
    activeStore = participantStore();
  });

  it('indexes a vote only while its source document still exists', async () => {
    activeStore = participantStore({ vote: { userId: 'user-1' } });
    await registerAppointmentParticipant('appointment-1', 'vote-1', 'user-1');
    assert.equal(activeStore.updates.length, 1);
    assert.equal(activeStore.updates[0][0], 'appointments/appointment-1');

    activeStore = participantStore();
    await registerAppointmentParticipant('appointment-1', 'vote-1', 'user-1');
    assert.deepEqual(activeStore.updates, []);
  });

  it('does not reintroduce a uid after account deletion is locked', async () => {
    activeStore = participantStore({
      vote: { userId: 'user-1' },
      lock: { startedAt: 'now' },
    });
    await registerAppointmentParticipant('appointment-1', 'vote-1', 'user-1');
    assert.deepEqual(activeStore.updates, []);
  });

  it('does not trust a stale event whose vote now belongs to another uid', async () => {
    activeStore = participantStore({ vote: { userId: 'user-2' } });
    await registerAppointmentParticipant('appointment-1', 'vote-1', 'user-1');
    assert.deepEqual(activeStore.updates, []);
  });
});
