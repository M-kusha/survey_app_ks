const assert = require('node:assert/strict');
const test = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const {
  appointmentConfirmationTransition,
  appointmentIsSettled,
} = require('../lib/appointment_state');

const startMillis = Date.parse('2026-08-10T09:00:00.000Z');
const canonical = (confirmedSlotId = 'slot_1') => ({
  schemaVersion: 2,
  confirmedSlotId,
  zoneId: 'Europe/Berlin',
  slots: [
    {
      slotId: 'slot_1',
      startAt: Timestamp.fromMillis(startMillis),
      endAt: Timestamp.fromMillis(startMillis + 3_600_000),
    },
  ],
});

test('extracts a newly confirmed canonical Timestamp and creator zone', () => {
  const transition = appointmentConfirmationTransition(
    canonical(null),
    canonical(),
  );

  assert.equal(transition.slotId, 'slot_1');
  assert.equal(transition.startAt.toISOString(), '2026-08-10T09:00:00.000Z');
  assert.equal(transition.zoneId, 'Europe/Berlin');
  assert.equal(appointmentIsSettled(canonical()), true);
  assert.equal(appointmentIsSettled(canonical(null)), false);
});

test('legacy confirmedTimeSlots and start strings never become canonical state', () => {
  const legacy = {
    confirmedTimeSlots: [{
      start: '2026-08-10T09:00:00.000Z',
      end: '2026-08-10T10:00:00.000Z',
    }],
    availableTimeSlots: [{
      start: '2026-08-10T09:00:00.000Z',
      end: '2026-08-10T10:00:00.000Z',
      isConfirmed: true,
    }],
    zoneId: 'Europe/Berlin',
  };

  assert.equal(appointmentConfirmationTransition({}, legacy), null);
  assert.equal(appointmentIsSettled(legacy), false);
});

test('does not parse a string start from an otherwise selected slot', () => {
  const transition = appointmentConfirmationTransition(canonical(null), {
    confirmedSlotId: 'slot_1',
    zoneId: 'Europe/Berlin',
    slots: [{ slotId: 'slot_1', start: '2026-08-10T09:00:00.000Z' }],
  });

  assert.equal(transition.slotId, 'slot_1');
  assert.equal(transition.startAt, undefined);
  assert.equal(transition.zoneId, 'Europe/Berlin');
});

test('does not reannounce an unchanged confirmation', () => {
  assert.equal(
    appointmentConfirmationTransition(canonical(), canonical()),
    null,
  );
});
