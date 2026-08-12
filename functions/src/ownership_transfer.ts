import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

import { hasRecentAuthentication } from './account_deletion';
import {
  ActivityCreateTransaction,
  writeCompanyActivity,
} from './activity_log';

type Data = Record<string, unknown>;
type MemberRole = 'user' | 'moderator' | 'admin' | 'superadmin';

type RequestTransfer = {
  action: 'request';
  targetUid: string;
};

type AcceptTransfer = {
  action: 'accept';
};

type ParsedTransfer = RequestTransfer | AcceptTransfer;

export type OwnershipTransferResult =
  | {
      requested: true;
      companyId: string;
      targetUid: string;
      expiresAtMillis: number;
    }
  | {
      transferred: true;
      companyId: string;
      formerOwnerUid: string;
      newOwnerUid: string;
      activityId: string;
    };

type ErrorCode =
  | 'invalid-argument'
  | 'failed-precondition'
  | 'permission-denied';

export class OwnershipTransferError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'OwnershipTransferError';
  }
}

type CompanyNameLock = {
  path: string;
  data: Data;
};

type OwnershipTransferTransaction = ActivityCreateTransaction & {
  get(path: string): Promise<Data | undefined>;
  listCompanyNameLocks(companyId: string): Promise<CompanyNameLock[]>;
  update(path: string, data: Data): void;
};

type AuthState = {
  emailVerified: boolean;
  disabled: boolean;
};

export type OwnershipTransferDependencies = {
  getAuthUser?: (uid: string) => Promise<AuthState>;
  runTransaction?: <T>(
    operation: (transaction: OwnershipTransferTransaction) => Promise<T>,
  ) => Promise<T>;
  newActivityId?: () => string;
  nowMillis?: () => number;
  serverTimestamp?: () => unknown;
  timestampFromMillis?: (millis: number) => unknown;
  deleteField?: () => unknown;
};

type MemberState = {
  companyId: string;
  role: MemberRole;
  membership: 'active' | 'pending';
};

type LoadedMember = {
  state?: MemberState;
  deletionLocked: boolean;
};

type TransferOffer = {
  fromUid: string;
  targetUid: string;
  requestedAtMillis: number;
  expiresAtMillis: number;
};

const transferLifetimeMillis = 48 * 60 * 60 * 1000;

function fail(code: ErrorCode, message: string): OwnershipTransferError {
  return new OwnershipTransferError(code, message);
}

function isRecord(value: unknown): value is Data {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function hasExactKeys(data: Data, expected: readonly string[]): boolean {
  const keys = Object.keys(data);
  return keys.length === expected.length &&
    keys.every((key) => expected.includes(key));
}

function validUid(value: unknown): value is string {
  return typeof value === 'string' &&
    value.length > 0 &&
    value.length <= 128 &&
    !value.includes('/');
}

function parseTransfer(payload: unknown): ParsedTransfer {
  if (!isRecord(payload) || typeof payload.action !== 'string') {
    throw fail('invalid-argument', 'ownership-transfer-request-invalid');
  }
  if (payload.action === 'accept') {
    if (!hasExactKeys(payload, ['action'])) {
      throw fail('invalid-argument', 'ownership-transfer-request-invalid');
    }
    return { action: 'accept' };
  }
  if (payload.action === 'request') {
    if (
      !hasExactKeys(payload, ['action', 'targetUid']) ||
      !validUid(payload.targetUid)
    ) {
      throw fail('invalid-argument', 'ownership-transfer-target-invalid');
    }
    return { action: 'request', targetUid: payload.targetUid };
  }
  throw fail('invalid-argument', 'ownership-transfer-request-invalid');
}

function timestampMillis(value: unknown): number | undefined {
  if (
    value != null &&
    typeof value === 'object' &&
    'toMillis' in value &&
    typeof (value as { toMillis?: unknown }).toMillis === 'function'
  ) {
    const millis = (value as { toMillis(): number }).toMillis();
    return Number.isFinite(millis) ? millis : undefined;
  }
  return undefined;
}

function memberState(profile: Data, directory: Data): MemberState | undefined {
  const companyId = profile.companyId;
  const fullName = profile.fullName;
  const role = profile.role;
  const membership = profile.membership;
  if (
    !validUid(companyId) ||
    typeof fullName !== 'string' ||
    fullName.length === 0 ||
    fullName.length > 120 ||
    !['user', 'moderator', 'admin', 'superadmin'].includes(String(role)) ||
    !['active', 'pending'].includes(String(membership))
  ) {
    return undefined;
  }
  if (
    directory.companyId !== companyId ||
    directory.fullName !== fullName ||
    directory.role !== role ||
    directory.membership !== membership
  ) {
    return undefined;
  }
  if (Object.keys(directory).some((key) => ![
    'fullName',
    'profileImage',
    'profileImageRevision',
    'companyId',
    'role',
    'membership',
  ].includes(key))) {
    return undefined;
  }

  const profileHasImage = Object.hasOwn(profile, 'profileImage');
  const directoryHasImage = Object.hasOwn(directory, 'profileImage');
  if (
    profileHasImage !== directoryHasImage ||
    (profileHasImage && (
      typeof profile.profileImage !== 'string' ||
      directory.profileImage !== profile.profileImage
    ))
  ) {
    return undefined;
  }

  const profileHasRevision = Object.hasOwn(profile, 'profileImageRevision');
  const directoryHasRevision = Object.hasOwn(directory, 'profileImageRevision');
  if (
    profileHasRevision !== directoryHasRevision ||
    (profileHasRevision && (
      typeof profile.profileImageRevision !== 'number' ||
      !Number.isInteger(profile.profileImageRevision) ||
      profile.profileImageRevision < 0 ||
      profile.profileImageRevision > 2_147_483_647 ||
      directory.profileImageRevision !== profile.profileImageRevision
    ))
  ) {
    return undefined;
  }

  return {
    companyId,
    role: role as MemberRole,
    membership: membership as 'active' | 'pending',
  };
}

async function loadMember(
  transaction: OwnershipTransferTransaction,
  uid: string,
): Promise<LoadedMember> {
  const [profile, directory, deletionLock] = await Promise.all([
    transaction.get(`users/${uid}`),
    transaction.get(`memberDirectory/${uid}`),
    transaction.get(`accountDeletionLocks/${uid}`),
  ]);
  return {
    state: profile && directory ? memberState(profile, directory) : undefined,
    deletionLocked: deletionLock != null,
  };
}

function ensureCompanyOpen(company: Data): void {
  if (
    Object.hasOwn(company, 'deletionScheduledFor') ||
    Object.hasOwn(company, 'deletionRequestedBy') ||
    Object.hasOwn(company, 'purgeStartedAt')
  ) {
    throw fail('failed-precondition', 'company-closing');
  }
}

function parseOffer(value: unknown): TransferOffer | undefined {
  if (
    !isRecord(value) ||
    !hasExactKeys(value, [
      'fromUid',
      'targetUid',
      'requestedAt',
      'expiresAt',
    ]) ||
    !validUid(value.fromUid) ||
    !validUid(value.targetUid) ||
    value.fromUid === value.targetUid
  ) {
    return undefined;
  }
  const requestedAtMillis = timestampMillis(value.requestedAt);
  const expiresAtMillis = timestampMillis(value.expiresAt);
  if (
    requestedAtMillis == null ||
    expiresAtMillis == null ||
    expiresAtMillis - requestedAtMillis !== transferLifetimeMillis
  ) {
    return undefined;
  }
  return {
    fromUid: value.fromUid,
    targetUid: value.targetUid,
    requestedAtMillis,
    expiresAtMillis,
  };
}

function validNameLock(
  lock: CompanyNameLock,
  companyId: string,
  ownerUid: string,
): boolean {
  const parts = lock.path.split('/');
  return parts.length === 2 &&
    parts[0] === 'companyNames' &&
    validUid(parts[1]) &&
    hasExactKeys(lock.data, ['companyId', 'createdBy']) &&
    lock.data.companyId === companyId &&
    lock.data.createdBy === ownerUid;
}

async function getLiveAuth(
  uid: string,
  dependencies: OwnershipTransferDependencies,
  unavailableMessage: string,
): Promise<AuthState> {
  const getAuthUser = dependencies.getAuthUser ?? (async (userId: string) => {
    const user = await getAuth().getUser(userId);
    return { emailVerified: user.emailVerified, disabled: user.disabled };
  });
  let auth: AuthState;
  try {
    auth = await getAuthUser(uid);
  } catch {
    throw fail('failed-precondition', unavailableMessage);
  }
  if (!auth.emailVerified || auth.disabled) {
    throw fail('failed-precondition', unavailableMessage);
  }
  return auth;
}

async function firestoreTransaction<T>(
  operation: (transaction: OwnershipTransferTransaction) => Promise<T>,
): Promise<T> {
  const db = getFirestore();
  return db.runTransaction((transaction) => operation({
    get: async (path) => {
      const snapshot = await transaction.get(db.doc(path));
      return snapshot.exists ? snapshot.data() : undefined;
    },
    listCompanyNameLocks: async (companyId) => {
      const snapshot = await transaction.get(
        db.collection('companyNames').where('companyId', '==', companyId),
      );
      return snapshot.docs.map((document) => ({
        path: document.ref.path,
        data: document.data(),
      }));
    },
    create: (path, data) => transaction.create(db.doc(path), data),
    update: (path, data) => transaction.update(db.doc(path), data),
  }));
}

async function requestTransfer(
  transaction: OwnershipTransferTransaction,
  uid: string,
  targetUid: string,
  nowMillis: number,
  timestampFromMillis: (millis: number) => unknown,
  verifyTargetAuth: () => Promise<void>,
): Promise<OwnershipTransferResult> {
  if (targetUid === uid) {
    throw fail('permission-denied', 'ownership-transfer-target-unavailable');
  }

  const actor = await loadMember(transaction, uid);
  if (actor.deletionLocked) {
    throw fail('failed-precondition', 'account-deletion-started');
  }
  if (!actor.state || actor.state.membership !== 'active') {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }

  const [company, actorBan, target] = await Promise.all([
    transaction.get(`companies/${actor.state.companyId}`),
    transaction.get(`companies/${actor.state.companyId}/bans/${uid}`),
    loadMember(transaction, targetUid),
  ]);
  if (!company || actorBan) {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }
  ensureCompanyOpen(company);
  if (actor.state.role !== 'superadmin' || company.createdBy !== uid) {
    throw fail('permission-denied', 'company-owner-required');
  }
  if (Object.hasOwn(company, 'ownershipTransfer')) {
    const existing = parseOffer(company.ownershipTransfer);
    if (!existing || existing.fromUid !== uid) {
      throw fail('failed-precondition', 'ownership-transfer-state-invalid');
    }
  }
  if (target.deletionLocked) {
    throw fail(
      'failed-precondition',
      'ownership-transfer-target-account-deleting',
    );
  }
  if (
    !target.state ||
    target.state.companyId !== actor.state.companyId ||
    target.state.membership !== 'active' ||
    target.state.role === 'superadmin'
  ) {
    throw fail('permission-denied', 'ownership-transfer-target-unavailable');
  }
  const targetBan = await transaction.get(
    `companies/${actor.state.companyId}/bans/${targetUid}`,
  );
  if (targetBan) {
    throw fail('permission-denied', 'ownership-transfer-target-unavailable');
  }

  await verifyTargetAuth();

  const expiresAtMillis = nowMillis + transferLifetimeMillis;
  transaction.update(`companies/${actor.state.companyId}`, {
    ownershipTransfer: {
      fromUid: uid,
      targetUid,
      requestedAt: timestampFromMillis(nowMillis),
      expiresAt: timestampFromMillis(expiresAtMillis),
    },
  });
  return {
    requested: true,
    companyId: actor.state.companyId,
    targetUid,
    expiresAtMillis,
  };
}

async function acceptTransfer(
  transaction: OwnershipTransferTransaction,
  uid: string,
  activityId: string,
  nowMillis: number,
  occurredAt: unknown,
  deletedField: unknown,
): Promise<OwnershipTransferResult> {
  const recipient = await loadMember(transaction, uid);
  if (recipient.deletionLocked) {
    throw fail('failed-precondition', 'account-deletion-started');
  }
  if (!recipient.state || recipient.state.membership !== 'active') {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }

  const companyId = recipient.state.companyId;
  const [company, recipientBan] = await Promise.all([
    transaction.get(`companies/${companyId}`),
    transaction.get(`companies/${companyId}/bans/${uid}`),
  ]);
  if (!company || recipientBan) {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }
  ensureCompanyOpen(company);
  if (!Object.hasOwn(company, 'ownershipTransfer')) {
    throw fail('failed-precondition', 'ownership-transfer-not-requested');
  }
  const offer = parseOffer(company.ownershipTransfer);
  if (!offer) {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }
  if (offer.targetUid !== uid) {
    throw fail('permission-denied', 'ownership-transfer-not-recipient');
  }
  if (nowMillis >= offer.expiresAtMillis) {
    throw fail('failed-precondition', 'ownership-transfer-expired');
  }
  if (
    company.createdBy !== offer.fromUid ||
    recipient.state.role === 'superadmin'
  ) {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }

  const [owner, ownerBan, nameLocks] = await Promise.all([
    loadMember(transaction, offer.fromUid),
    transaction.get(`companies/${companyId}/bans/${offer.fromUid}`),
    transaction.listCompanyNameLocks(companyId),
  ]);
  if (owner.deletionLocked) {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }
  if (
    !owner.state ||
    owner.state.companyId !== companyId ||
    owner.state.membership !== 'active' ||
    owner.state.role !== 'superadmin' ||
    ownerBan ||
    nameLocks.length !== 1 ||
    !validNameLock(nameLocks[0], companyId, offer.fromUid)
  ) {
    throw fail('failed-precondition', 'ownership-transfer-state-invalid');
  }

  transaction.update(`companies/${companyId}`, {
    createdBy: uid,
    ownershipTransfer: deletedField,
  });
  transaction.update(nameLocks[0].path, { createdBy: uid });
  transaction.update(`users/${offer.fromUid}`, { role: 'admin' });
  transaction.update(`memberDirectory/${offer.fromUid}`, { role: 'admin' });
  transaction.update(`users/${uid}`, { role: 'superadmin' });
  transaction.update(`memberDirectory/${uid}`, { role: 'superadmin' });
  writeCompanyActivity(transaction, {
    id: activityId,
    companyId,
    action: 'company.ownership_transferred',
    actorUid: offer.fromUid,
    targetUid: uid,
    occurredAt,
    before: { ownerUid: offer.fromUid },
    after: { ownerUid: uid },
  });

  return {
    transferred: true,
    companyId,
    formerOwnerUid: offer.fromUid,
    newOwnerUid: uid,
    activityId,
  };
}

export async function transferCompanyOwnershipForUser(
  uid: string,
  authTime: unknown,
  payload: unknown,
  dependencies: OwnershipTransferDependencies = {},
): Promise<OwnershipTransferResult> {
  if (!validUid(uid)) {
    throw fail(
      'failed-precondition',
      'ownership-transfer-account-unavailable',
    );
  }
  const request = parseTransfer(payload);
  const nowMillis = (dependencies.nowMillis ?? Date.now)();
  if (
    !Number.isFinite(nowMillis) ||
    !hasRecentAuthentication(authTime, Math.floor(nowMillis / 1000))
  ) {
    throw fail('failed-precondition', 'recent-login-required');
  }

  await getLiveAuth(
    uid,
    dependencies,
    'ownership-transfer-account-unavailable',
  );

  const runTransaction = dependencies.runTransaction ?? firestoreTransaction;
  if (request.action === 'request') {
    const timestampFromMillis = dependencies.timestampFromMillis ??
      Timestamp.fromMillis;
    return runTransaction((transaction) => requestTransfer(
      transaction,
      uid,
      request.targetUid,
      nowMillis,
      timestampFromMillis,
      async () => {
        await getLiveAuth(
          request.targetUid,
          dependencies,
          'ownership-transfer-target-account-unavailable',
        );
      },
    ));
  }

  const activityId = (dependencies.newActivityId ?? (() =>
    getFirestore().collection('companies').doc().id))();
  if (!validUid(activityId)) {
    throw new Error('Generated activity identity is invalid.');
  }
  const serverTimestamp = dependencies.serverTimestamp ?? FieldValue.serverTimestamp;
  const deleteField = dependencies.deleteField ?? FieldValue.delete;
  return runTransaction((transaction) => acceptTransfer(
    transaction,
    uid,
    activityId,
    nowMillis,
    serverTimestamp(),
    deleteField(),
  ));
}
