import { getAuth } from 'firebase-admin/auth';
import {
  DocumentReference,
  FieldValue,
  Firestore,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';

import { purgeCompany } from './purge';

export const deletedAuthorId = '__deleted_account__';

export class CompanyOwnerDeletionError extends Error {
  constructor() {
    super('Company deletion must be explicitly authorized with account deletion.');
    this.name = 'CompanyOwnerDeletionError';
  }
}

type OwnedCompany = {
  id: string;
  ref: DocumentReference;
};

export async function establishAccountDeletionWriteBarrier(
  db: Pick<Firestore, 'collection' | 'runTransaction'>,
  uid: string,
  deleteOwnedCompany: boolean,
  nowMillis = Date.now(),
): Promise<OwnedCompany[]> {
  const accountLock = db.collection('accountDeletionLocks').doc(uid);
  const ownedCompanyQuery = db
    .collection('companies')
    .where('createdBy', '==', uid);

  return db.runTransaction(async (transaction) => {
    const ownedCompany = await transaction.get(ownedCompanyQuery);
    if (!ownedCompany.empty && !deleteOwnedCompany) {
      throw new CompanyOwnerDeletionError();
    }
    if (ownedCompany.size > 400) {
      throw new Error('Account owns too many companies for an atomic deletion lock.');
    }

    transaction.set(accountLock, {
      startedAt: FieldValue.serverTimestamp(),
      expiresAt: Timestamp.fromMillis(nowMillis + 2 * 60 * 60 * 1000),
    });
    for (const company of ownedCompany.docs) {
      transaction.update(company.ref, {
        deletionScheduledFor: Timestamp.fromMillis(nowMillis),
        deletionRequestedBy: uid,
      });
    }
    return ownedCompany.docs.map((company) => ({
      id: company.id,
      ref: company.ref,
    }));
  });
}

export function hasRecentAuthentication(
  authTime: unknown,
  nowSeconds = Math.floor(Date.now() / 1000),
  maxAgeSeconds = 5 * 60,
): boolean {
  return (
    typeof authTime === 'number' &&
    Number.isFinite(authTime) &&
    authTime <= nowSeconds + 60 &&
    nowSeconds - authTime <= maxAgeSeconds
  );
}

export async function deleteUserAccount(
  uid: string,
  options: { deleteOwnedCompany?: boolean } = {},
): Promise<void> {
  const db = getFirestore();

  const ownedCompanies = await establishAccountDeletionWriteBarrier(
    db,
    uid,
    options.deleteOwnedCompany === true,
  );

  const ownedNameLocks = await Promise.all(
    ownedCompanies.map((company) =>
      db.collection('companyNames').where('companyId', '==', company.id).get(),
    ),
  );
  if (ownedNameLocks.some((locks) => locks.size + 2 > 450)) {
    throw new Error(
      'An owned company has too many name locks for an atomic final purge.',
    );
  }

  for (const company of ownedCompanies) {
    await purgeCompany(company.id);
  }

  await deleteProfileImage(uid);
  await anonymizeAuthoredContent(db, uid);
  await cleanBanReferences(db, uid);
  await deleteParticipation(db, uid);
  await deletePrivateNotes(db, uid);

  await deleteReferences(db, [
    db.collection('memberDirectory').doc(uid),
    db.collection('users').doc(uid),
  ]);

  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if ((error as { code?: unknown } | null)?.code !== 'auth/user-not-found') {
      throw error;
    }
  }
}

export async function purgeExpiredAccountDeletionLocks(): Promise<number> {
  const db = getFirestore();
  const expired = await db
    .collection('accountDeletionLocks')
    .where('expiresAt', '<=', Timestamp.now())
    .get();
  await deleteReferences(
    db,
    expired.docs.map((doc) => doc.ref),
  );
  return expired.size;
}

async function deleteProfileImage(uid: string): Promise<void> {
  const bucket = getStorage().bucket();
  await Promise.all([
    bucket
      .file(`profile_images/${uid}.jpg`)
      .delete({ ignoreNotFound: true }),
    bucket
      .file(`profile_images/${uid}/avatar.jpg`)
      .delete({ ignoreNotFound: true }),
  ]);
}

async function anonymizeAuthoredContent(
  db: Firestore,
  uid: string,
): Promise<void> {
  const [surveys, appointments] = await Promise.all([
    db.collection('surveys').where('createdBy', '==', uid).get(),
    db.collection('appointments').where('createdBy', '==', uid).get(),
  ]);

  await updateReferences(
    db,
    [...surveys.docs, ...appointments.docs].map((doc) => doc.ref),
    { createdBy: deletedAuthorId },
  );
}

async function cleanBanReferences(db: Firestore, uid: string): Promise<void> {
  const companies = await db.collection('companies').get();
  const ownBans: DocumentReference[] = [];
  const authoredBans: DocumentReference[] = [];

  for (const companyChunk of chunked(companies.docs, 25)) {
    const snapshots = await Promise.all(
      companyChunk.map((company) => company.ref.collection('bans').get()),
    );
    for (const bans of snapshots) {
      for (const ban of bans.docs) {
        if (ban.id === uid) {
          ownBans.push(ban.ref);
        } else if (ban.get('bannedBy') === uid) {
          authoredBans.push(ban.ref);
        }
      }
    }
  }

  await deleteReferences(db, ownBans);
  await updateReferences(db, authoredBans, { bannedBy: deletedAuthorId });
}

async function deleteParticipation(db: Firestore, uid: string): Promise<void> {
  const participation = await db
    .collectionGroup('participants')
    .where('userId', '==', uid)
    .get();
  await deleteReferences(
    db,
    participation.docs.map((doc) => doc.ref),
  );

  const indexedAppointments = await db
    .collection('appointments')
    .where('participantUserIds', 'array-contains', uid)
    .get();
  await updateReferences(
    db,
    indexedAppointments.docs.map((doc) => doc.ref),
    { participantUserIds: FieldValue.arrayRemove(uid) },
  );
}

async function deletePrivateNotes(db: Firestore, uid: string): Promise<void> {
  const profileNotes = await db
    .collection('users')
    .doc(uid)
    .collection('notes')
    .get();
  const noteRoot = db.collection('notes').doc(uid);
  const userNotes = await noteRoot.collection('userNotes').get();

  await deleteReferences(db, [
    ...profileNotes.docs.map((doc) => doc.ref),
    ...userNotes.docs.map((doc) => doc.ref),
    noteRoot,
  ]);
}

async function deleteReferences(
  db: Firestore,
  references: DocumentReference[],
): Promise<void> {
  for (const chunk of chunked(references)) {
    const batch = db.batch();
    for (const reference of chunk) batch.delete(reference);
    await batch.commit();
  }
}

async function updateReferences(
  db: Firestore,
  references: DocumentReference[],
  values: Record<string, unknown>,
): Promise<void> {
  for (const chunk of chunked(references)) {
    const batch = db.batch();
    for (const reference of chunk) batch.update(reference, values);
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
