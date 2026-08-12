import { FieldValue, getFirestore } from 'firebase-admin/firestore';

export async function registerAppointmentParticipant(
  appointmentId: string,
  participantId: string,
  userId: unknown,
): Promise<void> {
  if (typeof userId !== 'string' || userId.length === 0) return;

  const db = getFirestore();
  const appointment = db.collection('appointments').doc(appointmentId);
  const vote = appointment.collection('participants').doc(participantId);
  const deletionLock = db.collection('accountDeletionLocks').doc(userId);

  await db.runTransaction(async (transaction) => {
    const [parent, currentVote, lock] = await transaction.getAll(
      appointment,
      vote,
      deletionLock,
    );
    if (!parent.exists || !currentVote.exists || lock.exists) return;
    if (currentVote.get('userId') !== userId) return;

    transaction.update(appointment, {
      participantUserIds: FieldValue.arrayUnion(userId),
    });
  });
}

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

    const remaining = await transaction.get(remainingVotes);
    if (!remaining.empty) return;

    transaction.update(appointment, {
      participantUserIds: FieldValue.arrayRemove(userId),
    });
  });
}
