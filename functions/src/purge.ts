import { getFirestore, Query } from 'firebase-admin/firestore';

import { activeMemberIds, notify } from './messaging';

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
export async function purgeCompany(companyId: string): Promise<void> {
  const db = getFirestore();

  // Told before it happens, not after. This is the last moment these people are
  // reachable as a group.
  const members = await activeMemberIds(companyId);
  const company = await db.collection('companies').doc(companyId).get();

  await notify(
    { userIds: members },
    {
      title: 'Company closed',
      body: `${company.get('name') ?? 'Your company'} has been deleted. Your account and notes are unaffected — you can join another company.`,
      data: { type: 'company_closed' },
    },
  ).catch(() => undefined);

  await purgeWithChildren(
    db.collection('surveys').where('companyId', '==', companyId),
    'participants',
  );
  await purgeWithChildren(
    db.collection('appointments').where('companyId', '==', companyId),
    'participants',
  );

  await deleteAll(db.collection('companies').doc(companyId).collection('bans'));
  await deleteAll(
    db.collection('companyNames').where('companyId', '==', companyId),
  );

  // Released, not deleted.
  const users = await db
    .collection('users')
    .where('companyId', '==', companyId)
    .get();

  for (const chunk of chunked(users.docs)) {
    const batch = db.batch();
    for (const user of chunk) {
      batch.update(user.ref, {
        companyId: '',
        role: 'user',
        membership: 'active',
      });
    }
    await batch.commit();
  }

  await db.collection('companies').doc(companyId).delete();
}

/** Deletes each parent's subcollection, then the parent. */
async function purgeWithChildren(
  parents: Query,
  childCollection: string,
): Promise<void> {
  const snapshot = await parents.get();

  for (const parent of snapshot.docs) {
    await deleteAll(parent.ref.collection(childCollection));
    await parent.ref.delete();
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
