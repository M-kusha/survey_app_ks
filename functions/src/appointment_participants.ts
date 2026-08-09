import { FieldValue, getFirestore } from 'firebase-admin/firestore';

/**
 * Maintains the appointment's compact voter index from trusted vote documents.
 *
 * `participantUserIds` is a display/query cache, never an authorization source.
 * Clients cannot write it. Firestore event delivery is at-least-once, so both
 * operations deliberately use idempotent array transforms.
 */
export async function registerAppointmentParticipant(
  appointmentId: string,
  userId: unknown,
): Promise<void> {
  if (typeof userId !== 'string' || userId.length === 0) return;

  const appointment = getFirestore().collection('appointments').doc(appointmentId);
  try {
    await appointment.update({
      participantUserIds: FieldValue.arrayUnion(userId),
    });
  } catch (error) {
    // Company/appointment purges delete children before their parent. A delayed
    // event for an already deleted parent is expected and has nothing to repair.
    if (!isNotFound(error)) throw error;
  }
}

/** Removes the uid only after its final vote document has gone. */
export async function unregisterAppointmentParticipant(
  appointmentId: string,
  userId: unknown,
): Promise<void> {
  if (typeof userId !== 'string' || userId.length === 0) return;

  const db = getFirestore();
  const appointment = db.collection('appointments').doc(appointmentId);
  const remainingVotes = appointment
    .collection('participants')
    .where('userId', '==', userId)
    .limit(1);

  await db.runTransaction(async (transaction) => {
    const parent = await transaction.get(appointment);
    if (!parent.exists) return;

    // Reading the matching query inside the transaction closes the delete/new
    // vote race: a matching insert forces a retry instead of letting an older
    // delete event remove a currently valid voter.
    const remaining = await transaction.get(remainingVotes);
    if (!remaining.empty) return;

    transaction.update(appointment, {
      participantUserIds: FieldValue.arrayRemove(userId),
    });
  });
}

function isNotFound(error: unknown): boolean {
  const code = (error as { code?: unknown } | null)?.code;
  return code === 5 || code === '5' || code === 'not-found';
}
