import {
  FieldValue,
  Firestore,
  Query,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

import { activeMemberIds, notify } from './messaging';
import { companyClosedCopy } from './notification_copy';

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
    throw new Error(
      `Company ${companyId} has too many name locks for an atomic final purge.`,
    );
  }

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

  const users = await db
    .collection('users')
    .where('companyId', '==', companyId)
    .get();

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

  await deleteAll(
    db.collection('memberDirectory').where('companyId', '==', companyId),
  );

  await deleteAll(
    db.collection('companies').doc(companyId).collection('activity'),
  );

  const finalBatch = db.batch();
  for (const nameLock of nameLocks.docs) finalBatch.delete(nameLock.ref);
  finalBatch.delete(db.collection('companyDirectory').doc(companyId));
  finalBatch.delete(db.collection('companies').doc(companyId));
  await finalBatch.commit();
  return true;
}

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

function chunked<T>(items: T[], size = 400): T[][] {
  const chunks: T[][] = [];
  for (let start = 0; start < items.length; start += size) {
    chunks.push(items.slice(start, start + size));
  }
  return chunks;
}
