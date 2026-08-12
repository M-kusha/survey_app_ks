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
  | 'account.email_changed'
  | 'survey.created'
  | 'survey.deleted'
  | 'appointment.created'
  | 'appointment.updated'
  | 'appointment.deleted'
  | 'appointment.slot_confirmed';

export type CompanyActivityEntity = {
  type: 'survey' | 'test' | 'appointment';
  id: string;
  title: string;
};

const contentActions = new Set<CompanyActivityAction>([
  'survey.created',
  'survey.deleted',
  'appointment.created',
  'appointment.updated',
  'appointment.deleted',
  'appointment.slot_confirmed',
]);

const titleLimit = 120;

type MemberRole = 'user' | 'moderator' | 'admin' | 'superadmin';
type Membership = 'active' | 'pending';
type JoinPolicy = 'open' | 'approval';

export type CompanyActivityState = {
  role?: MemberRole;
  membership?: Membership;
  joinPolicy?: JoinPolicy;
  ownerUid?: string;
  deletionScheduledFor?: { toMillis(): number };
  confirmedStartAt?: { toMillis(): number };
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
  entity?: CompanyActivityEntity;
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
  'confirmedStartAt',
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
  ...contentActions,
]);

function validId(value: string): boolean {
  return value.length > 0 && value.length <= 128 && !value.includes('/');
}

function validEventId(value: string): boolean {
  return value.length > 0 && value.length <= 400 && !value.includes('/');
}

function assertSafeEntity(
  action: CompanyActivityAction,
  entity: CompanyActivityEntity | undefined,
): void {
  if (!entity) {
    if (contentActions.has(action)) {
      throw new Error('Content activity must name its subject.');
    }
    return;
  }
  if (!contentActions.has(action)) {
    throw new Error('Only content activity may name a subject.');
  }
  if (Object.keys(entity).some((key) => !['type', 'id', 'title'].includes(key))) {
    throw new Error('Activity subject contains a forbidden field.');
  }
  if (!['survey', 'test', 'appointment'].includes(entity.type)) {
    throw new Error('Activity subject has an invalid type.');
  }
  if (!validId(entity.id)) throw new Error('Activity subject has an invalid ID.');
  if (typeof entity.title !== 'string' || entity.title.length > titleLimit) {
    throw new Error('Activity subject has an invalid title.');
  }
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
  for (const instant of [state.deletionScheduledFor, state.confirmedStartAt]) {
    if (
      instant != null &&
      (typeof instant.toMillis !== 'function' ||
        !Number.isFinite(instant.toMillis()))
    ) {
      throw new Error('Activity state contains an invalid timestamp.');
    }
  }
}

export function activityTitle(value: unknown): string {
  if (typeof value !== 'string') return '';
  const trimmed = value.trim();
  return trimmed.length > titleLimit ? trimmed.slice(0, titleLimit) : trimmed;
}

export function companyActivityDocument(input: CompanyActivityInput): {
  path: string;
  event: Record<string, unknown>;
} {
  if (
    !validEventId(input.id) ||
    !validId(input.companyId) ||
    !validId(input.actorUid) ||
    (input.targetUid != null && !validId(input.targetUid)) ||
    !allowedActions.has(input.action)
  ) {
    throw new Error('Activity identity or action is invalid.');
  }
  assertSafeEntity(input.action, input.entity);
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
  if (input.entity) event.entity = input.entity;
  if (input.before) event.before = input.before;
  if (input.after) event.after = input.after;
  return { path: `companies/${input.companyId}/activity/${input.id}`, event };
}

export function writeCompanyActivity(
  transaction: ActivityCreateTransaction,
  input: CompanyActivityInput,
): void {
  const { path, event } = companyActivityDocument(input);
  transaction.create(path, event);
}
