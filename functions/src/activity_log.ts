export type CompanyActivityAction =
  | 'member.approved'
  | 'member.role_changed'
  | 'member.banned'
  | 'member.unbanned'
  | 'member.removed'
  | 'member.company_data_erased'
  | 'company.join_policy_changed'
  | 'company.deletion_scheduled'
  | 'company.deletion_cancelled'
  | 'company.created'
  | 'company.ownership_transferred'
  | 'account.email_changed';

type MemberRole = 'user' | 'moderator' | 'admin' | 'superadmin';
type Membership = 'active' | 'pending';
type JoinPolicy = 'open' | 'approval';

export type CompanyActivityState = {
  role?: MemberRole;
  membership?: Membership;
  joinPolicy?: JoinPolicy;
  ownerUid?: string;
  deletionScheduledFor?: { toMillis(): number };
};

export type ActivityCreateTransaction = {
  create(path: string, data: Record<string, unknown>): void;
};

export type CompanyActivityInput = {
  id: string;
  companyId: string;
  action: CompanyActivityAction;
  actorUid: string;
  targetUid?: string;
  occurredAt: unknown;
  before?: CompanyActivityState;
  after?: CompanyActivityState;
};

const allowedStateKeys = new Set([
  'role',
  'membership',
  'joinPolicy',
  'ownerUid',
  'deletionScheduledFor',
]);

const allowedActions = new Set<CompanyActivityAction>([
  'member.approved',
  'member.role_changed',
  'member.banned',
  'member.unbanned',
  'member.removed',
  'member.company_data_erased',
  'company.join_policy_changed',
  'company.deletion_scheduled',
  'company.deletion_cancelled',
  'company.created',
  'company.ownership_transferred',
  'account.email_changed',
]);

function validId(value: string): boolean {
  return value.length > 0 && value.length <= 128 && !value.includes('/');
}

function assertSafeState(state: CompanyActivityState | undefined): void {
  if (!state) return;
  if (Object.keys(state).some((key) => !allowedStateKeys.has(key))) {
    throw new Error('Activity state contains a forbidden field.');
  }
  if (
    state.role != null &&
    !['user', 'moderator', 'admin', 'superadmin'].includes(state.role)
  ) {
    throw new Error('Activity state contains an invalid role.');
  }
  if (
    state.membership != null &&
    !['active', 'pending'].includes(state.membership)
  ) {
    throw new Error('Activity state contains an invalid membership.');
  }
  if (
    state.joinPolicy != null &&
    !['open', 'approval'].includes(state.joinPolicy)
  ) {
    throw new Error('Activity state contains an invalid join policy.');
  }
  if (state.ownerUid != null && !validId(state.ownerUid)) {
    throw new Error('Activity state contains an invalid owner UID.');
  }
  if (
    state.deletionScheduledFor != null &&
    (
      typeof state.deletionScheduledFor.toMillis !== 'function' ||
      !Number.isFinite(state.deletionScheduledFor.toMillis())
    )
  ) {
    throw new Error('Activity state contains an invalid deletion timestamp.');
  }
}

/**
 * Appends one immutable, PII-free company event through a trusted transaction.
 * The narrow state type intentionally cannot hold names, emails, tokens,
 * content, URLs or whole document snapshots.
 */
export function writeCompanyActivity(
  transaction: ActivityCreateTransaction,
  input: CompanyActivityInput,
): void {
  if (
    !validId(input.id) ||
    !validId(input.companyId) ||
    !validId(input.actorUid) ||
    (input.targetUid != null && !validId(input.targetUid)) ||
    !allowedActions.has(input.action)
  ) {
    throw new Error('Activity identity or action is invalid.');
  }
  assertSafeState(input.before);
  assertSafeState(input.after);
  const event: Record<string, unknown> = {
    schemaVersion: 1,
    companyId: input.companyId,
    action: input.action,
    actorUid: input.actorUid,
    occurredAt: input.occurredAt,
  };
  if (input.targetUid) event.targetUid = input.targetUid;
  if (input.before) event.before = input.before;
  if (input.after) event.after = input.after;
  transaction.create(
    `companies/${input.companyId}/activity/${input.id}`,
    event,
  );
}
