import { getAuth } from 'firebase-admin/auth';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { createHash } from 'node:crypto';

import { hasRecentAuthentication } from './account_deletion';
import {
  ActivityCreateTransaction,
  writeCompanyActivity,
} from './activity_log';

type Data = Record<string, unknown>;

export type CompanyCreationResult = {
  created: true;
  companyId: string;
  role: 'superadmin';
  activityId: string;
};

type ErrorCode =
  | 'invalid-argument'
  | 'failed-precondition'
  | 'already-exists';

export class CompanyCreationError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'CompanyCreationError';
  }
}

type CompanyCreationTransaction = ActivityCreateTransaction & {
  get(path: string): Promise<Data | undefined>;
  update(path: string, data: Data): void;
};

export type CompanyCreationDependencies = {
  getAuthUser?: (
    uid: string,
  ) => Promise<{ emailVerified: boolean; disabled: boolean }>;
  runTransaction?: <T>(
    operation: (transaction: CompanyCreationTransaction) => Promise<T>,
  ) => Promise<T>;
  newCompanyId?: () => string;
  newActivityId?: () => string;
  nowMillis?: () => number;
  serverTimestamp?: () => unknown;
};

function creationError(
  code: ErrorCode,
  message: string,
): CompanyCreationError {
  return new CompanyCreationError(code, message);
}

function isRecord(value: unknown): value is Data {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function hasExactKeys(data: Data, expected: readonly string[]): boolean {
  const keys = Object.keys(data);
  return keys.length === expected.length &&
    keys.every((key) => expected.includes(key));
}

function validDocumentId(value: string): boolean {
  return value.length > 0 && value.length <= 128 && !value.includes('/');
}

export function companyNameSlug(name: string): string {
  const legacyCompatible = name
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  if (legacyCompatible) return legacyCompatible;

  const unicodeName = name.trim().normalize('NFKC').toLocaleLowerCase('en-US');
  if (!/[\p{L}\p{N}]/u.test(unicodeName)) return '';
  return `unicode-${createHash('sha256').update(unicodeName).digest('hex')}`;
}

function parseCompanyName(payload: unknown): string {
  if (
    !isRecord(payload) ||
    !hasExactKeys(payload, ['companyName']) ||
    typeof payload.companyName !== 'string'
  ) {
    throw creationError(
      'invalid-argument',
      'company-creation-request-invalid',
    );
  }
  const name = payload.companyName.trim();
  if (!name || name.length > 120 || !companyNameSlug(name)) {
    throw creationError('invalid-argument', 'company-name-invalid');
  }
  return name;
}

function memberProjection(uid: string, profile: Data): Data {
  if (
    typeof profile.fullName !== 'string' ||
    !profile.fullName.trim() ||
    profile.fullName.length > 120
  ) {
    throw creationError(
      'failed-precondition',
      'company-creation-profile-invalid',
    );
  }

  const projection: Data = {
    fullName: profile.fullName,
    companyId: '',
    role: 'superadmin',
    membership: 'active',
  };
  if (Object.hasOwn(profile, 'profileImage')) {
    if (profile.profileImage !== `profile_images/${uid}/avatar.jpg`) {
      throw creationError(
        'failed-precondition',
        'company-creation-profile-invalid',
      );
    }
    projection.profileImage = profile.profileImage;
  }
  if (Object.hasOwn(profile, 'profileImageRevision')) {
    if (
      typeof profile.profileImageRevision !== 'number' ||
      !Number.isInteger(profile.profileImageRevision) ||
      profile.profileImageRevision < 0 ||
      profile.profileImageRevision > 2_147_483_647
    ) {
      throw creationError(
        'failed-precondition',
        'company-creation-profile-invalid',
      );
    }
    projection.profileImageRevision = profile.profileImageRevision;
  }
  return projection;
}

export function writeCompanyCreatedActivity(
  transaction: ActivityCreateTransaction,
  input: {
    id: string;
    companyId: string;
    actorUid: string;
    occurredAt: unknown;
  },
): void {
  writeCompanyActivity(transaction, {
    ...input,
    action: 'company.created',
    after: { ownerUid: input.actorUid },
  });
}

async function firestoreTransaction<T>(
  operation: (transaction: CompanyCreationTransaction) => Promise<T>,
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

export async function createCompanyForCurrentUser(
  uid: string,
  authTime: unknown,
  payload: unknown,
  dependencies: CompanyCreationDependencies = {},
): Promise<CompanyCreationResult> {
  const name = parseCompanyName(payload);
  const nowMillis = (dependencies.nowMillis ?? Date.now)();
  if (!hasRecentAuthentication(authTime, Math.floor(nowMillis / 1000))) {
    throw creationError('failed-precondition', 'recent-login-required');
  }

  const getAuthUser = dependencies.getAuthUser ?? (async (userId: string) => {
    const user = await getAuth().getUser(userId);
    return { emailVerified: user.emailVerified, disabled: user.disabled };
  });
  let authUser: { emailVerified: boolean; disabled: boolean };
  try {
    authUser = await getAuthUser(uid);
  } catch {
    throw creationError(
      'failed-precondition',
      'company-creation-account-unavailable',
    );
  }
  if (!authUser.emailVerified || authUser.disabled) {
    throw creationError(
      'failed-precondition',
      'company-creation-account-unavailable',
    );
  }

  const newCompanyId = dependencies.newCompanyId ??
    (() => getFirestore().collection('companies').doc().id);
  const newActivityId = dependencies.newActivityId ??
    (() => getFirestore().collection('companies').doc().id);
  const companyId = newCompanyId();
  const activityId = newActivityId();
  if (!validDocumentId(companyId) || !validDocumentId(activityId)) {
    throw new Error('Generated company identity is invalid.');
  }

  const runTransaction = dependencies.runTransaction ?? firestoreTransaction;
  const serverTimestamp = dependencies.serverTimestamp ?? FieldValue.serverTimestamp;
  const slug = companyNameSlug(name);

  return runTransaction(async (transaction) => {
    const [profile, deletionLock, existingMember, nameLock] = await Promise.all([
      transaction.get(`users/${uid}`),
      transaction.get(`accountDeletionLocks/${uid}`),
      transaction.get(`memberDirectory/${uid}`),
      transaction.get(`companyNames/${slug}`),
    ]);
    if (!profile) {
      throw creationError(
        'failed-precondition',
        'company-creation-profile-invalid',
      );
    }
    if (
      Object.hasOwn(profile, 'pendingOnboardingType') ||
      Object.hasOwn(profile, 'pendingCompanyName') ||
      Object.hasOwn(profile, 'pendingCompanyId')
    ) {
      throw creationError('failed-precondition', 'onboarding-pending');
    }
    if (deletionLock) {
      throw creationError('failed-precondition', 'account-deletion-started');
    }
    if (existingMember) {
      throw creationError(
        'failed-precondition',
        'company-membership-state-invalid',
      );
    }
    if (
      profile.companyId !== '' ||
      profile.role !== 'user' ||
      profile.membership !== 'active'
    ) {
      throw creationError(
        'failed-precondition',
        'company-creation-profile-invalid',
      );
    }
    if (nameLock) {
      throw creationError('already-exists', 'company-name-taken');
    }

    const timestamp = serverTimestamp();
    const projection = memberProjection(uid, profile);
    projection.companyId = companyId;

    transaction.create(`companyNames/${slug}`, {
      companyId,
      createdBy: uid,
    });
    transaction.create(`companies/${companyId}`, {
      name,
      createdBy: uid,
      createdAt: timestamp,
      joinPolicy: 'open',
    });
    transaction.create(`companyDirectory/${companyId}`, {
      name,
      joinPolicy: 'open',
    });
    transaction.create(`memberDirectory/${uid}`, projection);
    transaction.update(`users/${uid}`, {
      companyId,
      companyName: name,
      role: 'superadmin',
      membership: 'active',
    });
    writeCompanyCreatedActivity(transaction, {
      id: activityId,
      companyId,
      actorUid: uid,
      occurredAt: timestamp,
    });

    return { created: true, companyId, role: 'superadmin', activityId };
  });
}
