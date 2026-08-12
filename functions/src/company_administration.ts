import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  Timestamp,
  getFirestore,
} from 'firebase-admin/firestore';

import { hasRecentAuthentication } from './account_deletion';
import {
  CompanyActivityAction,
  CompanyActivityInput,
  writeCompanyActivity,
} from './activity_log';

export type CompanyAdministrationAction =
  | 'approveMember'
  | 'changeMemberRole'
  | 'banMember'
  | 'unbanMember'
  | 'removeMember'
  | 'eraseMemberCompanyData'
  | 'setJoinPolicy'
  | 'scheduleDeletion'
  | 'cancelDeletion';

type MemberRole = 'user' | 'moderator' | 'admin' | 'superadmin';
type AssignableRole = Exclude<MemberRole, 'superadmin'>;
type Membership = 'active' | 'pending';
type JoinPolicy = 'open' | 'approval';
type Data = Record<string, unknown>;

type ParsedRequest =
  | { action: 'approveMember'; targetUid: string }
  | { action: 'changeMemberRole'; targetUid: string; role: AssignableRole }
  | { action: 'banMember'; targetUid: string }
  | { action: 'unbanMember'; targetUid: string }
  | { action: 'removeMember'; targetUid: string }
  | { action: 'eraseMemberCompanyData'; targetUid: string }
  | { action: 'setJoinPolicy'; joinPolicy: JoinPolicy }
  | { action: 'scheduleDeletion' }
  | { action: 'cancelDeletion' };

export type CompanyAdministrationResult = {
  completed: true;
  action: CompanyAdministrationAction;
  activityId: string;
  companyId: string;
  targetUid?: string;
  membership?: Membership;
  role?: AssignableRole;
  released?: true;
  joinPolicy?: JoinPolicy;
  deletionScheduledForMillis?: number;
  cancelled?: true;
};

type ErrorCode =
  | 'invalid-argument'
  | 'failed-precondition'
  | 'permission-denied'
  | 'not-found';

export class CompanyAdministrationError extends Error {
  constructor(
    readonly code: ErrorCode,
    message: string,
  ) {
    super(message);
    this.name = 'CompanyAdministrationError';
  }
}

const deleteField = Symbol('delete-field');

type AdministrationTransaction = {
  get(path: string): Promise<Data | undefined>;
  create(path: string, data: Data): void;
  update(path: string, data: Data): void;
  delete(path: string): void;
};

export type CompanyAdministrationDependencies = {
  getAuthUser?: (
    uid: string,
  ) => Promise<{ emailVerified: boolean; disabled: boolean }>;
  runTransaction?: <T>(
    operation: (transaction: AdministrationTransaction) => Promise<T>,
  ) => Promise<T>;
  listCompanyParticipantPaths?: (
    companyId: string,
    targetUid: string,
  ) => Promise<string[]>;
  newActivityId?: () => string;
  nowMillis?: () => number;
  serverTimestamp?: () => unknown;
};

type MemberState = {
  companyId: string;
  fullName: string;
  role: MemberRole;
  membership: Membership;
};

type ActorContext = MemberState & {
  company: Data;
};

type TargetContext = MemberState & {
  ban?: Data;
  detached: boolean;
};

const targetActions = new Set<CompanyAdministrationAction>([
  'approveMember',
  'changeMemberRole',
  'banMember',
  'unbanMember',
  'removeMember',
  'eraseMemberCompanyData',
]);

const activityActions: Record<CompanyAdministrationAction, CompanyActivityAction> = {
  approveMember: 'member.approved',
  changeMemberRole: 'member.role_changed',
  banMember: 'member.banned',
  unbanMember: 'member.unbanned',
  removeMember: 'member.removed',
  eraseMemberCompanyData: 'member.company_data_erased',
  setJoinPolicy: 'company.join_policy_changed',
  scheduleDeletion: 'company.deletion_scheduled',
  cancelDeletion: 'company.deletion_cancelled',
};

function administrationError(
  code: ErrorCode,
  message: string,
): CompanyAdministrationError {
  return new CompanyAdministrationError(code, message);
}

function isRecord(value: unknown): value is Data {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function hasExactKeys(data: Data, expected: readonly string[]): boolean {
  const keys = Object.keys(data);
  return keys.length === expected.length && keys.every((key) => expected.includes(key));
}

function validUid(value: unknown): value is string {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    value.length <= 128 &&
    !value.includes('/')
  );
}

function parseRequest(payload: unknown): ParsedRequest {
  if (!isRecord(payload) || typeof payload.action !== 'string') {
    throw administrationError('invalid-argument', 'administration-request-invalid');
  }

  const action = payload.action as CompanyAdministrationAction;
  if (!(action in activityActions)) {
    throw administrationError('invalid-argument', 'administration-action-invalid');
  }

  if (targetActions.has(action)) {
    const expected = action === 'changeMemberRole'
      ? ['action', 'targetUid', 'role']
      : ['action', 'targetUid'];
    if (!hasExactKeys(payload, expected) || !validUid(payload.targetUid)) {
      throw administrationError('invalid-argument', 'member-target-invalid');
    }
    if (action === 'changeMemberRole') {
      if (!['user', 'moderator', 'admin'].includes(String(payload.role))) {
        throw administrationError('invalid-argument', 'member-role-invalid');
      }
      return {
        action,
        targetUid: payload.targetUid,
        role: payload.role as AssignableRole,
      };
    }
    return { action, targetUid: payload.targetUid } as ParsedRequest;
  }

  if (action === 'setJoinPolicy') {
    if (
      !hasExactKeys(payload, ['action', 'joinPolicy']) ||
      !['open', 'approval'].includes(String(payload.joinPolicy))
    ) {
      throw administrationError('invalid-argument', 'join-policy-invalid');
    }
    return { action, joinPolicy: payload.joinPolicy as JoinPolicy };
  }

  if (!hasExactKeys(payload, ['action'])) {
    throw administrationError('invalid-argument', 'administration-request-invalid');
  }
  return { action } as ParsedRequest;
}

function memberState(profile: Data, directory: Data): MemberState | undefined {
  const companyId = profile.companyId;
  const fullName = profile.fullName;
  const role = profile.role;
  const membership = profile.membership;
  if (
    typeof companyId !== 'string' ||
    companyId.length === 0 ||
    companyId.length > 128 ||
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
  const directoryKeys = Object.keys(directory);
  if (directoryKeys.some((key) => ![
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
    fullName,
    role: role as MemberRole,
    membership: membership as Membership,
  };
}

async function readActor(
  transaction: AdministrationTransaction,
  uid: string,
): Promise<ActorContext> {
  const [profile, directory, accountLock] = await Promise.all([
    transaction.get(`users/${uid}`),
    transaction.get(`memberDirectory/${uid}`),
    transaction.get(`accountDeletionLocks/${uid}`),
  ]);
  if (!profile) {
    throw administrationError('failed-precondition', 'administration-profile-missing');
  }
  if (accountLock) {
    throw administrationError('failed-precondition', 'administration-account-deleting');
  }
  if (!directory) {
    throw administrationError('permission-denied', 'administration-membership-required');
  }
  const actor = memberState(profile, directory);
  if (!actor || actor.membership !== 'active') {
    throw administrationError('permission-denied', 'administration-membership-required');
  }
  if (!['admin', 'superadmin'].includes(actor.role)) {
    throw administrationError('permission-denied', 'administration-role-required');
  }

  const [company, ban] = await Promise.all([
    transaction.get(`companies/${actor.companyId}`),
    transaction.get(`companies/${actor.companyId}/bans/${uid}`),
  ]);
  if (!company) {
    throw administrationError('not-found', 'company-not-found');
  }
  if (ban) {
    throw administrationError('permission-denied', 'administration-banned');
  }
  return { ...actor, company };
}

async function readTarget(
  transaction: AdministrationTransaction,
  actor: ActorContext,
  actorUid: string,
  targetUid: string,
  allowDetachedBanned = false,
): Promise<TargetContext> {
  if (targetUid === actorUid) {
    throw administrationError('permission-denied', 'member-self-operation-denied');
  }
  const [profile, directory, accountLock, ban] = await Promise.all([
    transaction.get(`users/${targetUid}`),
    transaction.get(`memberDirectory/${targetUid}`),
    transaction.get(`accountDeletionLocks/${targetUid}`),
    transaction.get(`companies/${actor.companyId}/bans/${targetUid}`),
  ]);
  if (accountLock) {
    throw administrationError('failed-precondition', 'member-account-deleting');
  }
  if (
    allowDetachedBanned &&
    ban
  ) {
    if (!profile && !directory) {
      return {
        companyId: actor.companyId,
        fullName: typeof ban.name === 'string' ? ban.name : '',
        role: 'user',
        membership: 'active',
        ban,
        detached: true,
      };
    }
    if (
      profile &&
      !directory &&
      profile.companyId === '' &&
      profile.role === 'user' &&
      profile.membership === 'active'
    ) {
      return {
        companyId: actor.companyId,
        fullName: typeof profile.fullName === 'string'
          ? profile.fullName
          : typeof ban.name === 'string'
            ? ban.name
            : '',
        role: 'user',
        membership: 'active',
        ban,
        detached: true,
      };
    }
    if (profile && directory) {
      const current = memberState(profile, directory);
      if (current && current.companyId !== actor.companyId) {
        return { ...current, ban, detached: true };
      }
    }
  }
  if (!profile || !directory) {
    throw administrationError('not-found', 'member-not-found');
  }
  if (profile.companyId !== actor.companyId || directory.companyId !== actor.companyId) {
    throw administrationError('permission-denied', 'member-company-mismatch');
  }
  const target = memberState(profile, directory);
  if (!target) {
    throw administrationError('failed-precondition', 'member-state-invalid');
  }
  if (target.role === 'superadmin') {
    throw administrationError('permission-denied', 'member-owner-protected');
  }
  return {
    ...target,
    ban,
    detached: false,
  };
}

function ensureCompanyOpen(actor: ActorContext, action: CompanyAdministrationAction): void {
  if ('purgeStartedAt' in actor.company) {
    throw administrationError('failed-precondition', 'company-purge-started');
  }
  const scheduled = actor.company.deletionScheduledFor;
  const requestedBy = actor.company.deletionRequestedBy;
  if ((scheduled == null) !== (requestedBy == null)) {
    throw administrationError('failed-precondition', 'company-deletion-state-invalid');
  }
  if (scheduled != null && action !== 'cancelDeletion') {
    throw administrationError('failed-precondition', 'company-closing');
  }
}

function ensureOwner(actor: ActorContext, uid: string): void {
  if (actor.role !== 'superadmin' || actor.company.createdBy !== uid) {
    throw administrationError('permission-denied', 'company-owner-required');
  }
}

function timestampMillis(value: unknown): number | undefined {
  if (
    value != null &&
    typeof value === 'object' &&
    'toMillis' in value &&
    typeof (value as { toMillis?: unknown }).toMillis === 'function'
  ) {
    const millis = (value as { toMillis: () => number }).toMillis();
    return Number.isFinite(millis) ? millis : undefined;
  }
  return undefined;
}

function writeActivity(
  transaction: AdministrationTransaction,
  input: CompanyActivityInput,
): void {
  writeCompanyActivity(transaction, input);
}

function updateMemberPair(
  transaction: AdministrationTransaction,
  targetUid: string,
  fields: Data,
): void {
  transaction.update(`users/${targetUid}`, fields);
  transaction.update(`memberDirectory/${targetUid}`, fields);
}

async function applyAdministration(
  transaction: AdministrationTransaction,
  uid: string,
  authTime: unknown,
  request: ParsedRequest,
  activityId: string,
  nowMillis: number,
  occurredAt: unknown,
  erasedParticipantPaths: readonly string[],
): Promise<CompanyAdministrationResult> {
  const actor = await readActor(transaction, uid);
  ensureCompanyOpen(actor, request.action);
  const companyId = actor.companyId;
  const base = {
    completed: true as const,
    action: request.action,
    activityId,
    companyId,
  };

  if ('targetUid' in request) {
    const target = await readTarget(
      transaction,
      actor,
      uid,
      request.targetUid,
      request.action === 'unbanMember' ||
        request.action === 'eraseMemberCompanyData',
    );
    const activity = {
      id: activityId,
      companyId,
      action: activityActions[request.action],
      actorUid: uid,
      targetUid: request.targetUid,
      occurredAt,
    };

    switch (request.action) {
      case 'approveMember':
        if (target.ban) {
          throw administrationError('failed-precondition', 'member-banned');
        }
        if (target.membership !== 'pending') {
          throw administrationError('failed-precondition', 'member-already-active');
        }
        updateMemberPair(transaction, request.targetUid, { membership: 'active' });
        writeActivity(transaction, {
          ...activity,
          before: { membership: 'pending' },
          after: { membership: 'active' },
        });
        return { ...base, targetUid: request.targetUid, membership: 'active' };

      case 'changeMemberRole':
        if (target.ban) {
          throw administrationError('failed-precondition', 'member-banned');
        }
        if (target.role === request.role) {
          throw administrationError('failed-precondition', 'member-role-unchanged');
        }
        updateMemberPair(transaction, request.targetUid, { role: request.role });
        writeActivity(transaction, {
          ...activity,
          before: { role: target.role },
          after: { role: request.role },
        });
        return { ...base, targetUid: request.targetUid, role: request.role };

      case 'banMember':
        if (target.ban) {
          throw administrationError('failed-precondition', 'member-already-banned');
        }
        transaction.create(`companies/${companyId}/bans/${request.targetUid}`, {
          name: target.fullName,
          bannedAt: occurredAt,
          bannedBy: uid,
          previousMembership: target.membership,
        });
        updateMemberPair(transaction, request.targetUid, { membership: 'pending' });
        writeActivity(transaction, {
          ...activity,
          before: { membership: target.membership },
          after: { membership: 'pending' },
        });
        return { ...base, targetUid: request.targetUid, membership: 'pending' };

      case 'unbanMember': {
        if (!target.ban) {
          throw administrationError('failed-precondition', 'member-not-banned');
        }
        if (!target.detached && target.membership !== 'pending') {
          throw administrationError('failed-precondition', 'member-state-invalid');
        }
        const restored = target.ban.previousMembership === 'pending'
          ? 'pending'
          : target.ban.previousMembership === 'active'
            ? 'active'
            : undefined;
        if (!restored) {
          throw administrationError('failed-precondition', 'member-ban-state-invalid');
        }
        transaction.delete(`companies/${companyId}/bans/${request.targetUid}`);
        if (!target.detached) {
          updateMemberPair(transaction, request.targetUid, { membership: restored });
        }
        writeActivity(transaction, target.detached
          ? activity
          : {
              ...activity,
              before: { membership: 'pending' },
              after: { membership: restored },
            });
        return {
          ...base,
          targetUid: request.targetUid,
          membership: target.detached ? target.membership : restored,
        };
      }

      case 'removeMember':
        if (target.ban) {
          throw administrationError('failed-precondition', 'member-banned');
        }
        transaction.update(`users/${request.targetUid}`, {
          companyId: '',
          role: 'user',
          membership: 'active',
        });
        transaction.delete(`memberDirectory/${request.targetUid}`);
        writeActivity(transaction, {
          ...activity,
          before: { role: target.role, membership: target.membership },
          after: { role: 'user', membership: 'active' },
        });
        return { ...base, targetUid: request.targetUid, released: true };

      case 'eraseMemberCompanyData':
        if (!target.ban) {
          throw administrationError('failed-precondition', 'member-not-banned');
        }
        for (const path of erasedParticipantPaths) {
          transaction.delete(path);
        }
        if (!target.detached) {
          transaction.update(`users/${request.targetUid}`, {
            companyId: '',
            role: 'user',
            membership: 'active',
          });
          transaction.delete(`memberDirectory/${request.targetUid}`);
        }
        if (target.ban) {
          transaction.delete(`companies/${companyId}/bans/${request.targetUid}`);
        }
        writeActivity(transaction, target.detached
          ? activity
          : {
              ...activity,
              before: { role: target.role, membership: target.membership },
              after: { role: 'user', membership: 'active' },
            });
        return { ...base, targetUid: request.targetUid, released: true };
    }
  }

  if (request.action === 'setJoinPolicy') {
    const directory = await transaction.get(`companyDirectory/${companyId}`);
    const current = actor.company.joinPolicy;
    if (
      !directory ||
      !['open', 'approval'].includes(String(current)) ||
      directory.joinPolicy !== current
    ) {
      throw administrationError('failed-precondition', 'company-state-invalid');
    }
    if (current === request.joinPolicy) {
      throw administrationError('failed-precondition', 'join-policy-unchanged');
    }
    const currentPolicy = current as JoinPolicy;
    transaction.update(`companies/${companyId}`, { joinPolicy: request.joinPolicy });
    transaction.update(`companyDirectory/${companyId}`, {
      joinPolicy: request.joinPolicy,
    });
    writeActivity(transaction, {
      id: activityId,
      companyId,
      action: activityActions[request.action],
      actorUid: uid,
      occurredAt,
      before: { joinPolicy: currentPolicy },
      after: { joinPolicy: request.joinPolicy },
    });
    return { ...base, joinPolicy: request.joinPolicy };
  }

  ensureOwner(actor, uid);
  if (request.action === 'scheduleDeletion') {
    if (!hasRecentAuthentication(authTime, Math.floor(nowMillis / 1000))) {
      throw administrationError('failed-precondition', 'recent-login-required');
    }
    const deletionScheduledForMillis = nowMillis + 7 * 24 * 60 * 60 * 1000;
    const deletionScheduledFor = Timestamp.fromMillis(deletionScheduledForMillis);
    transaction.update(`companies/${companyId}`, {
      deletionScheduledFor,
      deletionRequestedBy: uid,
    });
    writeActivity(transaction, {
      id: activityId,
      companyId,
      action: activityActions[request.action],
      actorUid: uid,
      occurredAt,
      after: { deletionScheduledFor },
    });
    return { ...base, deletionScheduledForMillis };
  }

  const scheduledMillis = timestampMillis(actor.company.deletionScheduledFor);
  if (scheduledMillis == null || actor.company.deletionRequestedBy !== uid) {
    throw administrationError(
      'failed-precondition',
      actor.company.deletionScheduledFor == null
        ? 'company-deletion-not-scheduled'
        : 'company-deletion-state-invalid',
    );
  }
  const deletionScheduledFor = actor.company.deletionScheduledFor as {
    toMillis(): number;
  };
  transaction.update(`companies/${companyId}`, {
    deletionScheduledFor: deleteField,
    deletionRequestedBy: deleteField,
  });
  writeActivity(transaction, {
    id: activityId,
    companyId,
    action: activityActions[request.action],
    actorUid: uid,
    occurredAt,
    before: { deletionScheduledFor },
  });
  return { ...base, cancelled: true };
}

function materializeWrite(data: Data): Data {
  return Object.fromEntries(
    Object.entries(data).map(([key, value]) => [
      key,
      value === deleteField ? FieldValue.delete() : value,
    ]),
  );
}

async function firestoreTransaction<T>(
  operation: (transaction: AdministrationTransaction) => Promise<T>,
): Promise<T> {
  const db = getFirestore();
  return db.runTransaction((transaction) => operation({
    get: async (path) => {
      const snapshot = await transaction.get(db.doc(path));
      return snapshot.exists ? snapshot.data() : undefined;
    },
    create: (path, data) => transaction.create(db.doc(path), materializeWrite(data)),
    update: (path, data) => transaction.update(db.doc(path), materializeWrite(data)),
    delete: (path) => transaction.delete(db.doc(path)),
  }));
}

async function listCompanyParticipantPaths(
  companyId: string,
  targetUid: string,
): Promise<string[]> {
  const db = getFirestore();
  const [surveys, appointments] = await Promise.all([
    db.collection('surveys').where('companyId', '==', companyId).get(),
    db.collection('appointments').where('companyId', '==', companyId).get(),
  ]);
  const paths = surveys.docs.map((survey) =>
    survey.ref.collection('participants').doc(targetUid).path);
  const voteSnapshots = await Promise.all(
    appointments.docs.map((appointment) =>
      appointment.ref
        .collection('participants')
        .where('userId', '==', targetUid)
        .get()),
  );
  for (const votes of voteSnapshots) {
    paths.push(...votes.docs.map((vote) => vote.ref.path));
  }
  return [...new Set(paths)];
}

export async function administerCompanyForUser(
  uid: string,
  authTime: unknown,
  payload: unknown,
  dependencies: CompanyAdministrationDependencies = {},
): Promise<CompanyAdministrationResult> {
  const request = parseRequest(payload);
  const getAuthUser = dependencies.getAuthUser ?? (async (userId: string) => {
    const user = await getAuth().getUser(userId);
    return { emailVerified: user.emailVerified, disabled: user.disabled };
  });
  let authUser: { emailVerified: boolean; disabled: boolean };
  try {
    authUser = await getAuthUser(uid);
  } catch {
    throw administrationError(
      'failed-precondition',
      'administration-account-unavailable',
    );
  }
  if (!authUser.emailVerified || authUser.disabled) {
    throw administrationError(
      'failed-precondition',
      'administration-account-unavailable',
    );
  }

  if (
    request.action === 'approveMember' ||
    request.action === 'changeMemberRole'
  ) {
    let targetAuth: { emailVerified: boolean; disabled: boolean };
    try {
      targetAuth = await getAuthUser(request.targetUid);
    } catch {
      throw administrationError(
        'failed-precondition',
        'member-account-unavailable',
      );
    }
    if (!targetAuth.emailVerified || targetAuth.disabled) {
      throw administrationError(
        'failed-precondition',
        'member-account-unavailable',
      );
    }
  }

  const runTransaction = dependencies.runTransaction ?? firestoreTransaction;
  const listParticipantPaths =
    dependencies.listCompanyParticipantPaths ?? listCompanyParticipantPaths;
  const activityId = (dependencies.newActivityId ?? (() =>
    getFirestore().collection('companies').doc().id))();
  const nowMillis = (dependencies.nowMillis ?? Date.now)();
  const serverTimestamp = dependencies.serverTimestamp ?? FieldValue.serverTimestamp;

  let erasedParticipantPaths: string[] = [];
  if (request.action === 'eraseMemberCompanyData') {
    const companyId = await runTransaction(async (transaction) => {
      const actor = await readActor(transaction, uid);
      ensureCompanyOpen(actor, request.action);
      const target = await readTarget(
        transaction,
        actor,
        uid,
        request.targetUid,
        true,
      );
      if (!target.ban) {
        throw administrationError('failed-precondition', 'member-not-banned');
      }
      return actor.companyId;
    });
    erasedParticipantPaths = await listParticipantPaths(
      companyId,
      request.targetUid,
    );
    if (erasedParticipantPaths.length > 400) {
      throw administrationError(
        'failed-precondition',
        'member-company-data-too-large',
      );
    }
  }

  return runTransaction((transaction) => applyAdministration(
    transaction,
    uid,
    authTime,
    request,
    activityId,
    nowMillis,
    serverTimestamp(),
    erasedParticipantPaths,
  ));
}
