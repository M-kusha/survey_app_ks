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

/** What a content event was about. Surveys and tests are told apart here. */
export type CompanyActivityEntity = {
  type: 'survey' | 'test' | 'appointment';
  id: string;
  title: string;
};

/** The actions that must name their subject, and may not name a member. */
const contentActions = new Set<CompanyActivityAction>([
  'survey.created',
  'survey.deleted',
  'appointment.created',
  'appointment.updated',
  'appointment.deleted',
  'appointment.slot_confirmed',
]);

/**
 * The longest title kept on an event.
 *
 * Long enough for any real title, short enough that the field cannot be used as
 * a place to smuggle a document into an immutable store.
 */
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

/**
 * Event IDs are composed, so they get their own bound.
 *
 * Every caller derives the ID from what the event is about — `survey-created-{id}`
 * and so on — which makes a retry land on the document it already wrote instead
 * of appending a second copy of the same event. A composed ID can therefore be
 * longer than the 128 characters a UID is held to, and refusing it would mean
 * refusing the content write that carries it.
 */
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

/**
 * Trims a title to what an event is allowed to carry.
 *
 * Call sites read titles straight off the document being acted on, so this is
 * where an over-long or non-string one stops. An empty result is kept rather
 * than rejected: an event that cannot name its subject is still worth more than
 * no event at all, and the app already falls back to the ID.
 */
export function activityTitle(value: unknown): string {
  if (typeof value !== 'string') return '';
  const trimmed = value.trim();
  return trimmed.length > titleLimit ? trimmed.slice(0, titleLimit) : trimmed;
}

/**
 * Validates one event and returns where it goes and what it says.
 *
 * The narrow state and entity types intentionally cannot hold emails, names,
 * tokens, answers, responses, URLs or whole document snapshots. A content
 * event does carry the title of the survey or appointment it is about, because
 * an audit trail that cannot say *which* meeting was deleted is not an audit
 * trail — and after the delete there is nowhere left to look the title up.
 * Titles are company-authored and already visible to every member; the readers
 * of this log are that company's owners and admins.
 */
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

/** Appends one immutable event as part of the change it records. */
export function writeCompanyActivity(
  transaction: ActivityCreateTransaction,
  input: CompanyActivityInput,
): void {
  const { path, event } = companyActivityDocument(input);
  transaction.create(path, event);
}
