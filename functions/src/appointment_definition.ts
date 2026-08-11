import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const maxMillis = 253_402_300_799_999;
const parentKeys = [
  'schemaVersion', 'revision', 'appointmentId', 'companyId', 'createdBy',
  'title', 'description', 'zoneId', 'expirationAt', 'slots', 'slotIds',
  'confirmedSlotId', 'participantUserIds', 'createdAt',
] as const;

type ErrorCode =
  | 'aborted'
  | 'already-exists'
  | 'failed-precondition'
  | 'invalid-argument'
  | 'not-found'
  | 'permission-denied';
type Slot = { slotId: string; startAtMillis: number; endAtMillis: number };
type Definition = {
  title: string;
  description: string;
  zoneId: string;
  expirationAtMillis: number;
  slots: Slot[];
};
type SaveRequest =
  | { action: 'create'; appointmentId: string; definition: Definition }
  | {
      action: 'update';
      appointmentId: string;
      expectedRevision: number;
      reopenVoting: boolean;
      definition: Definition;
    };
type StoredSlot = { slotId: string; startAt: Timestamp; endAt: Timestamp };
type StoredAppointment = {
  revision: number;
  companyId: string;
  createdBy: string;
  createdAt: Timestamp;
  confirmedSlotId: string | null;
  participantUserIds: string[];
  slots: StoredSlot[];
};

export type SaveAppointmentDefinitionResult = {
  appointmentId: string;
  revision: number;
};
export class AppointmentDefinitionError extends Error {
  constructor(readonly code: ErrorCode, message: string) {
    super(message);
    this.name = 'AppointmentDefinitionError';
  }
}

interface AppointmentTransaction {
  get(path: string): Promise<Record<string, unknown> | undefined>;
  create(path: string, data: Record<string, unknown>): void;
  set(path: string, data: Record<string, unknown>): void;
}
export type AppointmentDefinitionDependencies = {
  runTransaction?: <T>(work: (transaction: AppointmentTransaction) => Promise<T>) => Promise<T>;
  getAuthUser?: (uid: string) => Promise<{ emailVerified: boolean; disabled: boolean }>;
  nowMillis?: () => number;
};

function fail(code: ErrorCode, message: string): never {
  throw new AppointmentDefinitionError(code, message);
}
function invalid(): never {
  throw new Error('appointment-definition-invalid');
}
function record(value: unknown): value is Record<string, unknown> {
  if (value == null || typeof value !== 'object' || Array.isArray(value)) return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}
function exact(value: Record<string, unknown>, keys: readonly string[]): boolean {
  const actual = Object.keys(value);
  return actual.length === keys.length && keys.every((key) => key in value);
}
function identifier(value: unknown): string {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(value)) invalid();
  return value;
}
function userId(value: unknown): string {
  if (typeof value !== 'string' || !value || value.length > 128 || value.includes('/')) invalid();
  return value;
}
function integer(value: unknown, minimum: number, maximum: number): number {
  if (!Number.isSafeInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    invalid();
  }
  return value as number;
}
function text(value: unknown, maximum: number, allowEmpty = false): string {
  if (typeof value !== 'string' || value.length > maximum || (!allowEmpty && !value.trim())) invalid();
  return value;
}
function canonicalZone(value: unknown): string {
  if (typeof value !== 'string' || !value || value.length > 128) invalid();
  try {
    return new Intl.DateTimeFormat('en', { timeZone: value }).resolvedOptions().timeZone;
  } catch {
    return invalid();
  }
}

function parseDefinition(raw: unknown): Definition {
  if (!record(raw) || !exact(raw, [
    'title', 'description', 'zoneId', 'expirationAtMillis', 'slots',
  ]) || !Array.isArray(raw.slots) || raw.slots.length < 1 || raw.slots.length > 100) {
    invalid();
  }
  const slots = raw.slots.map((rawSlot): Slot => {
    if (!record(rawSlot) || !exact(rawSlot, ['slotId', 'startAtMillis', 'endAtMillis'])) invalid();
    const startAtMillis = integer(rawSlot.startAtMillis, 0, maxMillis);
    const endAtMillis = integer(rawSlot.endAtMillis, 0, maxMillis);
    if (endAtMillis <= startAtMillis) invalid();
    return { slotId: identifier(rawSlot.slotId), startAtMillis, endAtMillis };
  });
  if (new Set(slots.map((slot) => slot.slotId)).size !== slots.length) invalid();
  slots.sort((a, b) =>
    a.startAtMillis - b.startAtMillis || a.endAtMillis - b.endAtMillis ||
      a.slotId.localeCompare(b.slotId),
  );
  return {
    title: text(raw.title, 160),
    description: text(raw.description, 5_000),
    zoneId: canonicalZone(raw.zoneId),
    expirationAtMillis: integer(raw.expirationAtMillis, 0, maxMillis),
    slots,
  };
}

function parseRequest(raw: unknown): SaveRequest {
  if (!record(raw)) return fail('invalid-argument', 'appointment-request-invalid');
  try {
    const appointmentId = identifier(raw.appointmentId);
    const definition = parseDefinition(raw.definition);
    if (raw.action === 'create' && exact(raw, ['action', 'appointmentId', 'definition'])) {
      return { action: 'create', appointmentId, definition };
    }
    if (raw.action === 'update' && exact(raw, [
      'action', 'appointmentId', 'expectedRevision', 'reopenVoting', 'definition',
    ]) && typeof raw.reopenVoting === 'boolean') {
      return {
        action: 'update', appointmentId, definition,
        expectedRevision: integer(raw.expectedRevision, 1, Number.MAX_SAFE_INTEGER - 1),
        reopenVoting: raw.reopenVoting,
      };
    }
  } catch {
    // Converted to the stable callable error below.
  }
  return fail('invalid-argument', 'appointment-request-invalid');
}

async function runFirestoreTransaction<T>(
  work: (transaction: AppointmentTransaction) => Promise<T>,
): Promise<T> {
  const firestore = getFirestore();
  return firestore.runTransaction((transaction) => work({
    get: async (path) => {
      const snapshot = await transaction.get(firestore.doc(path));
      return snapshot.exists ? snapshot.data() : undefined;
    },
    create: (path, data) => transaction.create(firestore.doc(path), data),
    set: (path, data) => transaction.set(firestore.doc(path), data),
  }));
}

async function authorizedCompany(transaction: AppointmentTransaction, uid: string): Promise<string> {
  const [profile, deletionLock] = await Promise.all([
    transaction.get(`users/${uid}`),
    transaction.get(`accountDeletionLocks/${uid}`),
  ]);
  if (!profile || deletionLock) fail('failed-precondition', 'appointment-author-account-unavailable');
  const companyId = typeof profile.companyId === 'string' ? profile.companyId : '';
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(companyId)) {
    fail('failed-precondition', 'appointment-author-membership-unavailable');
  }
  const [member, company, ban] = await Promise.all([
    transaction.get(`memberDirectory/${uid}`),
    transaction.get(`companies/${companyId}`),
    transaction.get(`companies/${companyId}/bans/${uid}`),
  ]);
  if (!member || !company || member.companyId !== companyId ||
      member.role !== profile.role || member.membership !== profile.membership) {
    fail('failed-precondition', 'appointment-author-membership-unavailable');
  }
  if ('deletionScheduledFor' in company) fail('failed-precondition', 'company-closing');
  if (ban) fail('permission-denied', 'company-banned');
  if (profile.membership !== 'active') fail('permission-denied', 'company-membership-inactive');
  if (!['admin', 'moderator', 'superadmin'].includes(String(profile.role))) {
    fail('permission-denied', 'appointment-author-role-required');
  }
  return companyId;
}

function timestamp(value: unknown): value is Timestamp {
  return value instanceof Timestamp;
}
function readStoredAppointment(
  data: Record<string, unknown>,
  appointmentId: string,
): StoredAppointment {
  try {
    if (!exact(data, parentKeys) || data.schemaVersion !== 2 ||
        data.appointmentId !== appointmentId || !Array.isArray(data.slots) ||
        !Array.isArray(data.slotIds) || !Array.isArray(data.participantUserIds) ||
        !timestamp(data.expirationAt) || !timestamp(data.createdAt)) invalid();
    const revision = integer(data.revision, 1, Number.MAX_SAFE_INTEGER - 1);
    const companyId = identifier(data.companyId);
    const createdBy = userId(data.createdBy);
    text(data.title, 160);
    text(data.description, 5_000);
    canonicalZone(data.zoneId);
    const slots = data.slots.map((raw): StoredSlot => {
      if (!record(raw) || !exact(raw, ['slotId', 'startAt', 'endAt']) ||
          !timestamp(raw.startAt) || !timestamp(raw.endAt)) invalid();
      return { slotId: identifier(raw.slotId), startAt: raw.startAt, endAt: raw.endAt };
    });
    const slotIds = data.slotIds.map(identifier);
    if (slots.length < 1 || slots.length > 100 ||
        slotIds.length !== slots.length ||
        slots.some((slot, index) => slot.slotId !== slotIds[index]) ||
        new Set(slotIds).size !== slotIds.length ||
        data.participantUserIds.some((id) => typeof id !== 'string' || !id || id.includes('/')) ||
        new Set(data.participantUserIds).size !== data.participantUserIds.length ||
        (data.confirmedSlotId !== null &&
          (typeof data.confirmedSlotId !== 'string' || !slotIds.includes(data.confirmedSlotId)))) invalid();
    return {
      revision, companyId, createdBy, createdAt: data.createdAt,
      confirmedSlotId: data.confirmedSlotId as string | null,
      participantUserIds: data.participantUserIds as string[], slots,
    };
  } catch {
    return fail('failed-precondition', 'appointment-state-invalid');
  }
}

function canonicalDocument(
  request: SaveRequest,
  companyId: string,
  revision: number,
  createdBy: string,
  createdAt: Timestamp,
  confirmedSlotId: string | null,
  participantUserIds: string[],
): Record<string, unknown> {
  const { definition } = request;
  return {
    schemaVersion: 2,
    revision,
    appointmentId: request.appointmentId,
    companyId,
    createdBy,
    title: definition.title,
    description: definition.description,
    zoneId: definition.zoneId,
    expirationAt: Timestamp.fromMillis(definition.expirationAtMillis),
    slots: definition.slots.map((slot) => ({
      slotId: slot.slotId,
      startAt: Timestamp.fromMillis(slot.startAtMillis),
      endAt: Timestamp.fromMillis(slot.endAtMillis),
    })),
    slotIds: definition.slots.map((slot) => slot.slotId),
    confirmedSlotId,
    participantUserIds,
    createdAt,
  };
}

/** Creates or revises one canonical appointment definition. */
export async function saveAppointmentDefinitionForUser(
  uid: string,
  rawRequest: unknown,
  dependencies: AppointmentDefinitionDependencies = {},
): Promise<SaveAppointmentDefinitionResult> {
  if (!uid || uid.length > 128 || uid.includes('/')) {
    fail('failed-precondition', 'appointment-author-account-unavailable');
  }
  const request = parseRequest(rawRequest);
  try {
    const getUser = dependencies.getAuthUser ?? (async (userId: string) => {
      const user = await getAuth().getUser(userId);
      return { emailVerified: user.emailVerified, disabled: user.disabled };
    });
    const user = await getUser(uid);
    if (!user.emailVerified || user.disabled) throw new Error();
  } catch {
    fail('failed-precondition', 'appointment-author-account-unavailable');
  }

  const runTransaction = dependencies.runTransaction ?? runFirestoreTransaction;
  return runTransaction(async (transaction) => {
    const companyId = await authorizedCompany(transaction, uid);
    const nowMillis = (dependencies.nowMillis ?? Date.now)();
    if (!Number.isSafeInteger(nowMillis) || nowMillis < 0) throw new Error('Invalid server clock.');
    const earliestStart = request.definition.slots[0].startAtMillis;
    if (request.definition.expirationAtMillis <= nowMillis ||
        request.definition.expirationAtMillis >= earliestStart) {
      fail('invalid-argument', 'appointment-deadline-invalid');
    }

    const path = `appointments/${request.appointmentId}`;
    const existingData = await transaction.get(path);
    if (request.action === 'create') {
      if (existingData) fail('already-exists', 'appointment-id-conflict');
      transaction.create(path, canonicalDocument(
        request, companyId, 1, uid, Timestamp.fromMillis(nowMillis), null, [],
      ));
      return { appointmentId: request.appointmentId, revision: 1 };
    }

    if (!existingData) fail('not-found', 'appointment-not-found');
    const existing = readStoredAppointment(existingData, request.appointmentId);
    if (existing.companyId !== companyId) fail('permission-denied', 'appointment-company-mismatch');
    if (existing.revision !== request.expectedRevision) {
      fail('aborted', 'appointment-revision-conflict');
    }
    const retained = new Map(existing.slots.map((slot) => [slot.slotId, slot]));
    for (const slot of request.definition.slots) {
      const previous = retained.get(slot.slotId);
      if (previous && (previous.startAt.toMillis() !== slot.startAtMillis ||
          previous.endAt.toMillis() !== slot.endAtMillis)) {
        fail('invalid-argument', 'appointment-slot-id-reused');
      }
    }
    const confirmedSlotId = request.reopenVoting ? null : existing.confirmedSlotId;
    if (confirmedSlotId && !request.definition.slots.some((slot) => slot.slotId === confirmedSlotId)) {
      fail('failed-precondition', 'appointment-confirmed-slot-removed');
    }
    const revision = existing.revision + 1;
    transaction.set(path, canonicalDocument(
      request, companyId, revision, existing.createdBy, existing.createdAt,
      confirmedSlotId, existing.participantUserIds,
    ));
    return { appointmentId: request.appointmentId, revision };
  });
}
