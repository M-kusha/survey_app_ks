import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';

import {
  ActivityCreateTransaction,
  writeCompanyActivity,
} from './activity_log';

type Data = Record<string, unknown>;

type EmailSyncTransaction = ActivityCreateTransaction & {
  get(path: string): Promise<Data | undefined>;
  update(path: string, data: Data): void;
};

type AuthEmailState = {
  email?: string;
  emailVerified: boolean;
  disabled: boolean;
};

export type EmailSyncDependencies = {
  getAuthUser?: (uid: string) => Promise<AuthEmailState>;
  runTransaction?: <T>(
    operation: (transaction: EmailSyncTransaction) => Promise<T>,
  ) => Promise<T>;
  newActivityId?: () => string;
  serverTimestamp?: () => unknown;
};

export type EmailSyncResult = {
  synced: true;
  changed: boolean;
};

type ErrorCode = 'invalid-argument' | 'failed-precondition';

export class EmailSyncError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'EmailSyncError';
  }
}

const memberRoles = new Set(['user', 'moderator', 'admin', 'superadmin']);
const projectionKeys = new Set([
  'fullName',
  'profileImage',
  'profileImageRevision',
  'companyId',
  'role',
  'membership',
]);

function fail(code: ErrorCode, message: string): EmailSyncError {
  return new EmailSyncError(code, message);
}

function isRecord(value: unknown): value is Data {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function validDocumentId(value: unknown): value is string {
  return typeof value === 'string' &&
    value.length > 0 &&
    value.length <= 128 &&
    !value.includes('/');
}

function parseExactEmptyPayload(payload: unknown): void {
  if (!isRecord(payload) || Object.keys(payload).length !== 0) {
    throw fail('invalid-argument', 'email-sync-request-invalid');
  }
}

function optionalFieldMatches(
  profile: Data,
  directory: Data,
  field: 'profileImage' | 'profileImageRevision',
): boolean {
  const inProfile = Object.hasOwn(profile, field);
  const inDirectory = Object.hasOwn(directory, field);
  return inProfile === inDirectory &&
    (!inProfile || profile[field] === directory[field]);
}

function canonicalActiveCompanyId(
  uid: string,
  profile: Data,
  directory: Data | undefined,
): string | undefined {
  if (!directory || Object.keys(directory).some((key) => !projectionKeys.has(key))) {
    return undefined;
  }
  const companyId = profile.companyId;
  if (
    !validDocumentId(companyId) ||
    typeof profile.fullName !== 'string' ||
    profile.fullName.length === 0 ||
    profile.fullName.length > 120 ||
    directory.fullName !== profile.fullName ||
    directory.companyId !== companyId ||
    !memberRoles.has(String(profile.role)) ||
    directory.role !== profile.role ||
    profile.membership !== 'active' ||
    directory.membership !== 'active' ||
    !optionalFieldMatches(profile, directory, 'profileImage') ||
    !optionalFieldMatches(profile, directory, 'profileImageRevision')
  ) {
    return undefined;
  }
  if (
    Object.hasOwn(profile, 'profileImage') &&
    (
      profile.profileImage !== `profile_images/${uid}/avatar.jpg` ||
      typeof directory.profileImage !== 'string'
    )
  ) {
    return undefined;
  }
  if (
    Object.hasOwn(profile, 'profileImageRevision') &&
    (
      typeof profile.profileImageRevision !== 'number' ||
      !Number.isInteger(profile.profileImageRevision) ||
      profile.profileImageRevision < 0 ||
      profile.profileImageRevision > 2_147_483_647
    )
  ) {
    return undefined;
  }
  return companyId;
}

function companyIsOpen(company: Data | undefined): boolean {
  return company != null &&
    !Object.hasOwn(company, 'deletionScheduledFor') &&
    !Object.hasOwn(company, 'deletionRequestedBy') &&
    !Object.hasOwn(company, 'purgeStartedAt');
}

async function firestoreTransaction<T>(
  operation: (transaction: EmailSyncTransaction) => Promise<T>,
): Promise<T> {
  const db = getFirestore();
  return db.runTransaction((transaction) => operation({
    get: async (path) => {
      const snapshot = await transaction.get(db.doc(path));
      return snapshot.exists ? snapshot.data() : undefined;
    },
    create: (path, data) => transaction.create(db.doc(path), data),
    update: (path, data) => transaction.update(db.doc(path), data),
  }));
}

export async function syncVerifiedEmailForUser(
  uid: string,
  payload: unknown,
  dependencies: EmailSyncDependencies = {},
): Promise<EmailSyncResult> {
  parseExactEmptyPayload(payload);
  if (!validDocumentId(uid)) {
    throw fail('failed-precondition', 'email-sync-account-unavailable');
  }

  const getAuthUser = dependencies.getAuthUser ?? (async (userId: string) => {
    const user = await getAuth().getUser(userId);
    return {
      email: user.email,
      emailVerified: user.emailVerified,
      disabled: user.disabled,
    };
  });
  let authUser: AuthEmailState;
  try {
    authUser = await getAuthUser(uid);
  } catch {
    throw fail('failed-precondition', 'email-sync-account-unavailable');
  }
  if (
    authUser.disabled ||
    !authUser.emailVerified ||
    typeof authUser.email !== 'string' ||
    authUser.email.trim().length === 0
  ) {
    throw fail('failed-precondition', 'email-sync-account-unavailable');
  }
  const verifiedEmail = authUser.email;
  const runTransaction = dependencies.runTransaction ?? firestoreTransaction;

  return runTransaction(async (transaction) => {
    const [profile, deletionLock] = await Promise.all([
      transaction.get(`users/${uid}`),
      transaction.get(`accountDeletionLocks/${uid}`),
    ]);
    if (!profile) {
      throw fail('failed-precondition', 'email-sync-profile-missing');
    }
    if (deletionLock) {
      throw fail('failed-precondition', 'account-deletion-started');
    }
    if (profile.email === verifiedEmail) {
      return { synced: true, changed: false };
    }

    const directory = await transaction.get(`memberDirectory/${uid}`);
    const companyId = canonicalActiveCompanyId(uid, profile, directory);
    let writeActivity = false;
    if (companyId) {
      const [company, ban] = await Promise.all([
        transaction.get(`companies/${companyId}`),
        transaction.get(`companies/${companyId}/bans/${uid}`),
      ]);
      writeActivity = companyIsOpen(company) && ban == null;
    }

    transaction.update(`users/${uid}`, { email: verifiedEmail });
    if (companyId && writeActivity) {
      const activityId = (dependencies.newActivityId ?? (() =>
        getFirestore().collection('companies').doc().id))();
      if (!validDocumentId(activityId)) {
        throw new Error('Generated activity identity is invalid.');
      }
      const serverTimestamp = dependencies.serverTimestamp ??
        FieldValue.serverTimestamp;
      writeCompanyActivity(transaction, {
        id: activityId,
        companyId,
        action: 'account.email_changed',
        actorUid: uid,
        occurredAt: serverTimestamp(),
      });
    }
    return { synced: true, changed: true };
  });
}
