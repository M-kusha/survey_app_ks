import { Timestamp } from 'firebase-admin/firestore';

export type AppointmentConfirmation = {
  slotId: string;
  startAt?: Date;
  zoneId?: string;
};

function record(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function confirmation(data: unknown): AppointmentConfirmation | null {
  if (!record(data) || typeof data.confirmedSlotId !== 'string' ||
      !data.confirmedSlotId) return null;
  const slotId = data.confirmedSlotId;
  const slots = Array.isArray(data.slots) ? data.slots : [];
  const slot = slots.find((candidate) =>
    record(candidate) && candidate.slotId === slotId,
  );
  const startAt = record(slot) && slot.startAt instanceof Timestamp
    ? slot.startAt.toDate()
    : undefined;
  const zoneId = typeof data.zoneId === 'string' && data.zoneId
    ? data.zoneId
    : undefined;
  return { slotId, startAt, zoneId };
}

export function appointmentConfirmationTransition(
  before: unknown,
  after: unknown,
): AppointmentConfirmation | null {
  const previous = confirmation(before);
  const next = confirmation(after);
  return next != null && next.slotId !== previous?.slotId ? next : null;
}

export function appointmentIsSettled(data: unknown): boolean {
  return confirmation(data) != null;
}
