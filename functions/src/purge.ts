import {
  FieldValue,
  Firestore,
  Query,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

import { activeMemberIds, notify } from './messaging';
import { companyClosedCopy } from './notification_copy';

/**
 * Destroys a company and everything that belonged to it.
 *
 * The same contract as the in-app version, and worth restating because it is
 * the whole reason this is safe to automate:
 *
 * * gone — every survey and its answers, every meeting and its votes, the ban
 *   list, the company document, its name reservation
 * * untouched — every person's account, password and notes
 *
 * Members are released rather than deleted. A company closing is not a reason
 * for somebody to lose their login, and they are free to join another one the
 * same day.
 *
 * Running server-side removes the awkward part of the client version: the admin
 * SDK is not subject to security rules, so nothing depends on the caller still
 * being a member while the deletes run, and nothing is stranded if whoever
 * requested it never opens the app again.
 */
/**
 * Serializes the scheduled purge against owner cancellation on the same
 * company document. Once claimed, cancellation fails closed and a retry may
 * safely continue an interrupted purge.
 */
export async function claimCompanyPurge(
  db: Pick<Firestore, 'collection' | 'runTransaction'>,
  companyId: string,
  nowMillis = Date.now(),
): Promise<boolean> {
  const companyRef = db.collection('companies').doc(companyId);
  return db.runTransaction(async (transaction) => {
    const company = await transaction.get(companyRef);
    if (!company.exists) return false;
    const data = company.data() ?? {};
    const scheduled = data.deletionScheduledFor;
    if (!(scheduled instanceof Timestamp) || scheduled.toMillis() > nowMillis) {
      return false;
    }
    if ('purgeStartedAt' in data) {
      if (!(data.purgeStartedAt instanceof Timestamp)) {
        throw new Error('Company purge marker is malformed.');
      }
      return true;
    }
    transaction.update(companyRef, {
      purgeStartedAt: FieldValue.serverTimestamp(),
    });
    return true;
  });
}

export async function purgeCompany(companyId: string): Promise<boolean> {
  const db = getFirestore();
  if (!(await claimCompanyPurge(db, companyId))) return false;

  const [company, nameLocks] = await Promise.all([
    db.collection('companies').doc(companyId).get(),
    db.collection('companyNames').where('companyId', '==', companyId).get(),
  ]);
  if (nameLocks.size + 2 > 450) {
    // Keep the uniqueness locks, public directory and company parent in one
    // final atomic batch. Malformed legacy state must fail before the first
    // destructive write rather than release names in a partial purge.
    throw new Error(
      `Company ${companyId} has too many name locks for an atomic final purge.`,
    );
  }

  // Told before it happens, not after. This is the last moment these people are
  // reachable as a group.
  const members = await activeMemberIds(companyId, { includeClosing: true });

  await notify(
    { userIds: members },
    (locale) => ({
      ...companyClosedCopy(locale, company.get('name')),
      data: { type: 'company_closed' },
    }),
  ).catch(() => undefined);

  await purgeWithChildren(
    db.collection('surveys').where('companyId', '==', companyId),
    'participants',
    'surveyAnswerKeys',
  );
  await purgeWithChildren(
    db.collection('appointments').where('companyId', '==', companyId),
    'participants',
  );

  await deleteAll(db.collection('companies').doc(companyId).collection('bans'));

  // Released, not deleted.
  const users = await db
    .collection('users')
    .where('companyId', '==', companyId)
    .get();

  // Each release updates the private profile and removes its company-visible
  // projection in the same batch. Two writes per member means 200 members keep
  // the batch safely below Firestore's 500-write limit.
  for (const chunk of chunked(users.docs, 200)) {
    const batch = db.batch();
    for (const user of chunk) {
      batch.update(user.ref, {
        companyId: '',
        role: 'user',
        membership: 'active',
      });
      batch.delete(db.collection('memberDirectory').doc(user.id));
    }
    await batch.commit();
  }

  // Also remove any orphaned legacy projection that had no private source
  // profile and therefore was not covered by the user loop above.
  await deleteAll(
    db.collection('memberDirectory').where('companyId', '==', companyId),
  );

  // Activity is retained until all content and membership cleanup succeeds.
  // A claimed purge cannot be cancelled, so a failure after this point can
  // only be resumed, never leave a live restored company without its history.
  await deleteAll(
    db.collection('companies').doc(companyId).collection('activity'),
  );

  // Release the canonical name only when every child and member cleanup has
  // succeeded. These final deletes commit atomically, so a retry can never see
  // a live company whose uniqueness lock was already released.
  const finalBatch = db.batch();
  for (const nameLock of nameLocks.docs) finalBatch.delete(nameLock.ref);
  finalBatch.delete(db.collection('companyDirectory').doc(companyId));
  finalBatch.delete(db.collection('companies').doc(companyId));
  await finalBatch.commit();
  return true;
}

/** Deletes each parent's subcollection, then the parent. */
async function purgeWithChildren(
  parents: Query,
  childCollection: string,
  pairedRootCollection?: string,
): Promise<void> {
  const db = getFirestore();
  const snapshot = await parents.get();

  for (const parent of snapshot.docs) {
    await deleteAll(parent.ref.collection(childCollection));
    const batch = db.batch();
    if (pairedRootCollection) {
      batch.delete(db.collection(pairedRootCollection).doc(parent.id));
    }
    batch.delete(parent.ref);
    await batch.commit();
  }
}

async function deleteAll(query: Query): Promise<void> {
  const db = getFirestore();
  const snapshot = await query.get();

  for (const chunk of chunked(snapshot.docs)) {
    const batch = db.batch();
    for (const doc of chunk) batch.delete(doc.ref);
    await batch.commit();
  }
}

/** Firestore batches cap at 500 writes. */
function chunked<T>(items: T[], size = 400): T[][] {
  const chunks: T[][] = [];
  for (let start = 0; start < items.length; start += size) {
    chunks.push(items.slice(start, start + size));
  }
  return chunks;
}
