import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import {
  activityTitle,
  companyActivityDocument,
  type CompanyActivityEntity,
  type CompanyActivityInput,
} from './activity_log';

type EntityType = 'survey' | 'appointment';
type ErrorCode = 'invalid-argument' | 'failed-precondition' |
  'permission-denied' | 'not-found';
type DeleteRequest = { entityType: EntityType; entityId: string };
type DeleteTarget = DeleteRequest & {
  parentPath: string;
  companyId: string;
  entity: CompanyActivityEntity;
};
interface DeletionTransaction {
  get(path: string): Promise<Record<string, unknown> | undefined>;
  update(path: string, data: Record<string, unknown>): void;
}
export type ContentDeletionDependencies = {
  getAuthUser?: (uid: string) => Promise<{ emailVerified: boolean; disabled: boolean }>;
  runTransaction?: <T>(work: (transaction: DeletionTransaction) => Promise<T>) => Promise<T>;
  deleteParticipants?: (parentPath: string) => Promise<void>;
  participantsRemain?: (parentPath: string) => Promise<boolean>;
  commitFinalDeletes?: (
    paths: string[],
    activity: CompanyActivityInput,
  ) => Promise<void>;
  nowMillis?: () => number;
};
export type DeleteContentResult = DeleteRequest & { deleted: true };

export class ContentDeletionError extends Error {
  constructor(readonly code: ErrorCode, message: string) {
    super(message);
    this.name = 'ContentDeletionError';
  }
}
function fail(code: ErrorCode, message: string): never {
  throw new ContentDeletionError(code, message);
}
function parseRequest(raw: unknown): DeleteRequest {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw) ||
      Object.keys(raw).length !== 2) {
    fail('invalid-argument', 'content-delete-request-invalid');
  }
  const { entityType, entityId } = raw as Record<string, unknown>;
  if ((entityType !== 'survey' && entityType !== 'appointment') ||
      typeof entityId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(entityId)) {
    fail('invalid-argument', 'content-delete-request-invalid');
  }
  return { entityType, entityId };
}

async function firestoreTransaction<T>(
  work: (transaction: DeletionTransaction) => Promise<T>,
): Promise<T> {
  const db = getFirestore();
  return db.runTransaction((transaction) => work({
    get: async (path) => {
      const snapshot = await transaction.get(db.doc(path));
      return snapshot.exists ? snapshot.data() : undefined;
    },
    update: (path, data) => transaction.update(db.doc(path), data),
  }));
}

async function establishBarrier(
  uid: string,
  request: DeleteRequest,
  nowMillis: number,
  runTransaction: NonNullable<ContentDeletionDependencies['runTransaction']>,
): Promise<DeleteTarget> {
  const root = request.entityType === 'survey' ? 'surveys' : 'appointments';
  const parentPath = `${root}/${request.entityId}`;
  return runTransaction(async (transaction) => {
    const target = await transaction.get(parentPath);
    if (!target) fail('not-found', 'content-not-found');
    const companyId = typeof target.companyId === 'string' ? target.companyId : '';
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(companyId)) {
      fail('failed-precondition', 'content-tenant-invalid');
    }
    const [profile, member, company, ban, accountLock] = await Promise.all([
      transaction.get(`users/${uid}`),
      transaction.get(`memberDirectory/${uid}`),
      transaction.get(`companies/${companyId}`),
      transaction.get(`companies/${companyId}/bans/${uid}`),
      transaction.get(`accountDeletionLocks/${uid}`),
    ]);
    if (!profile || !member || !company || accountLock) {
      fail('failed-precondition', 'content-delete-account-unavailable');
    }
    if (profile.companyId !== companyId || member.companyId !== companyId ||
        profile.role !== member.role || profile.membership !== 'active' ||
        member.membership !== 'active') {
      fail('permission-denied', 'content-delete-membership-required');
    }
    if (ban) fail('permission-denied', 'content-delete-banned');
    if (!['admin', 'moderator', 'superadmin'].includes(String(profile.role))) {
      fail('permission-denied', 'content-delete-role-required');
    }
    if ('deletionStartedAt' in target) {
      if (!(target.deletionStartedAt instanceof Timestamp)) {
        fail('failed-precondition', 'content-delete-state-invalid');
      }
    } else {
      transaction.update(parentPath, {
        deletionStartedAt: Timestamp.fromMillis(nowMillis),
      });
    }
    return {
      ...request,
      parentPath,
      companyId,
      entity: {
        type: request.entityType === 'appointment' ? 'appointment'
          : target.surveyType === 1 ? 'test' : 'survey',
        id: request.entityId,
        title: activityTitle(
          request.entityType === 'survey' ? target.surveyName : target.title,
        ),
      },
    };
  });
}

async function deleteParticipants(parentPath: string): Promise<void> {
  const db = getFirestore();
  const participants = await db.collection(`${parentPath}/participants`).get();
  for (let start = 0; start < participants.size; start += 400) {
    const batch = db.batch();
    for (const doc of participants.docs.slice(start, start + 400)) batch.delete(doc.ref);
    await batch.commit();
  }
}
async function participantsRemain(parentPath: string): Promise<boolean> {
  return !(await getFirestore().collection(`${parentPath}/participants`)
    .limit(1).get()).empty;
}
async function commitFinalDeletes(
  paths: string[],
  activity: CompanyActivityInput,
): Promise<void> {
  const db = getFirestore();
  const batch = db.batch();
  const activityDocument = companyActivityDocument(activity);
  batch.create(db.doc(activityDocument.path), activityDocument.event);
  for (const path of paths) batch.delete(db.doc(path));
  await batch.commit();
}

/** Deletes one survey or appointment only after its server-owned write barrier. */
export async function deleteContentForUser(
  uid: string,
  rawRequest: unknown,
  dependencies: ContentDeletionDependencies = {},
): Promise<DeleteContentResult> {
  if (!uid || uid.length > 128 || uid.includes('/')) {
    fail('failed-precondition', 'content-delete-account-unavailable');
  }
  const request = parseRequest(rawRequest);
  const nowMillis = (dependencies.nowMillis ?? Date.now)();
  if (!Number.isSafeInteger(nowMillis) || nowMillis < 0) {
    throw new Error('Invalid server clock.');
  }
  try {
    const getUser = dependencies.getAuthUser ?? (async (userId: string) => {
      const user = await getAuth().getUser(userId);
      return { emailVerified: user.emailVerified, disabled: user.disabled };
    });
    const user = await getUser(uid);
    if (!user.emailVerified || user.disabled) throw new Error();
  } catch {
    fail('failed-precondition', 'content-delete-account-unavailable');
  }

  const target = await establishBarrier(
    uid, request, nowMillis, dependencies.runTransaction ?? firestoreTransaction,
  );
  await (dependencies.deleteParticipants ?? deleteParticipants)(target.parentPath);
  if (await (dependencies.participantsRemain ?? participantsRemain)(target.parentPath)) {
    throw new Error('Content descendants remain after deletion sweep.');
  }
  await (dependencies.commitFinalDeletes ?? commitFinalDeletes)(
    [
      ...(request.entityType === 'survey'
        ? [`surveyAnswerKeys/${request.entityId}`]
        : []),
      target.parentPath,
    ],
    {
      id: `${request.entityType}-deleted-${request.entityId}`,
      companyId: target.companyId,
      action: request.entityType === 'survey' ? 'survey.deleted'
        : 'appointment.deleted',
      actorUid: uid,
      entity: target.entity,
      occurredAt: Timestamp.fromMillis(nowMillis),
    },
  );
  return { ...request, deleted: true };
}
