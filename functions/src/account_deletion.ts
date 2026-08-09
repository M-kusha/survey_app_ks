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

/** Callable account deletion requires a reauthentication no more than 5 minutes ago. */
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

/**
 * Idempotently removes one account's personal data, then deletes Auth last.
 *
 * Every Firestore/Storage operation is safe to repeat. If any cleanup step
 * fails, the Auth record is intentionally retained so the signed-in person can
 * retry instead of being locked out with data stranded behind them.
 */
export async function deleteUserAccount(
  uid: string,
  options: { deleteOwnedCompany?: boolean } = {},
): Promise<void> {
  const db = getFirestore();

  // Do not trust the client profile/role. Query the ownership source directly
  // before performing the first destructive operation.
  const ownedCompany = await db
    .collection('companies')
    .where('createdBy', '==', uid)
    .get();
  if (!ownedCompany.empty && options.deleteOwnedCompany !== true) {
    throw new CompanyOwnerDeletionError();
  }

  if (ownedCompany.size > 400) {
    // Current rules permit a single owned company. Refuse malformed legacy
    // state rather than splitting the write barrier across non-atomic batches.
    throw new Error('Account owns too many companies for an atomic deletion lock.');
  }

  const ownedNameLocks = await Promise.all(
    ownedCompany.docs.map((company) =>
      db.collection('companyNames').where('companyId', '==', company.id).get(),
    ),
  );
  if (ownedNameLocks.some((locks) => locks.size + 2 > 450)) {
    throw new Error(
      'An owned company has too many name locks for an atomic final purge.',
    );
  }

  // Establish both write barriers before enumerating any tenant content. The
  // account lock blocks every client write from this uid, while an immediately
  // due company-deletion marker makes companyAcceptsContent/Joins false for all
  // other sessions. Keeping these writes in one batch closes the orphan race in
  // which an admin created content after purgeCompany had queried its parents.
  const lockBatch = db.batch();
  lockBatch.set(db.collection('accountDeletionLocks').doc(uid), {
    startedAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromMillis(Date.now() + 2 * 60 * 60 * 1000),
  });
  for (const company of ownedCompany.docs) {
    lockBatch.update(company.ref, {
      deletionScheduledFor: Timestamp.now(),
      deletionRequestedBy: uid,
    });
  }
  await lockBatch.commit();

  // Account deletion is an explicit escape hatch from the normal seven-day
  // company-closure grace period. The client gives owners a separate warning;
  // the server independently proves ownership and deletes every owned tenant
  // before personal cleanup. Multiple documents are handled defensively for
  // malformed legacy data even though current rules permit only one.
  for (const company of ownedCompany.docs) {
    await purgeCompany(company.id);
  }

  await deleteProfileImage(uid);
  await anonymizeAuthoredContent(db, uid);
  await cleanBanReferences(db, uid);
  await deleteParticipation(db, uid);
  await deletePrivateNotes(db, uid);

  // The public member projection and private account/token document are
  // deliberately removed at the trusted boundary, not by client rules.
  await deleteReferences(db, [
    db.collection('memberDirectory').doc(uid),
    db.collection('users').doc(uid),
  ]);

  // Auth is the final destructive step. A missing user means a duplicated
  // callable invocation already completed the same idempotent deletion.
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    if ((error as { code?: unknown } | null)?.code !== 'auth/user-not-found') {
      throw error;
    }
  }
}

/**
 * Deletes temporary write locks after Firebase ID tokens issued before Auth
 * deletion have expired. Failed deletions unlock automatically and remain
 * retryable rather than stranding an account forever.
 */
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
  // Existing ban documents predate a userId field. Walk each known company's
  // subcollection so legacy bans are covered without requiring a new
  // collection-group index before account deletion can work.
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

  // This cache is server-derived for new votes, but legacy rows and delayed
  // triggers can still contain the uid. Sweep it explicitly before Auth goes.
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

/** Firestore batches cap at 500 writes; leave headroom for future markers. */
function chunked<T>(items: T[], size = 400): T[][] {
  const chunks: T[][] = [];
  for (let start = 0; start < items.length; start += size) {
    chunks.push(items.slice(start, start + size));
  }
  return chunks;
}
