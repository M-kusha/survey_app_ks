import { getAuth } from 'firebase-admin/auth';
import { Timestamp, getFirestore } from 'firebase-admin/firestore';
import { activityTitle, writeCompanyActivity } from './activity_log';

const limits = {
  deadline: 253_402_300_799_999,
  definitionBytes: 750_000,
  description: 5_000,
  option: 1_000,
  options: 50,
  question: 4_000,
  questions: 100,
  surveyName: 160,
};

type QuestionType = 'Single' | 'Multiple' | 'Text';
type PublicQuestion = { type: QuestionType; question: string; options?: string[] };
type QuestionKey =
  | { type: 'Single'; correctAnswer?: number }
  | { type: 'Multiple'; correctAnswers?: number[] }
  | { type: 'Text' };
type ValidatedDefinition = {
  publicDefinition: {
    surveyName: string;
    surveyDescription: string;
    deadlineMillis: number;
    timeLimitPerQuestion: number;
    surveyType: 0 | 1;
    questions: PublicQuestion[];
  };
  questionKeys: QuestionKey[];
};
type ErrorCode =
  | 'invalid-argument'
  | 'failed-precondition'
  | 'permission-denied'
  | 'already-exists';

export type SaveSurveyDefinitionResult = {
  surveyId: string;
};
export class SurveyPublicationError extends Error {
  constructor(readonly code: ErrorCode, message: string) {
    super(message);
    this.name = 'SurveyPublicationError';
  }
}

interface PublicationTransaction {
  get(path: string): Promise<Record<string, unknown> | undefined>;
  create(path: string, data: Record<string, unknown>): void;
}
export type SurveyPublicationDependencies = {
  runTransaction?: <T>(work: (transaction: PublicationTransaction) => Promise<T>) => Promise<T>;
  getAuthUser?: (uid: string) => Promise<{ emailVerified: boolean; disabled: boolean }>;
  nowMillis?: () => number;
};

function fail(code: ErrorCode, message: string): never {
  throw new SurveyPublicationError(code, message);
}
function invalid(): never {
  throw new Error('survey-definition-invalid');
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
function textValue(value: unknown, maximum: number, empty = false): string {
  if (typeof value !== 'string' || value.length > maximum || (!empty && !value.trim())) invalid();
  return value;
}
function integer(value: unknown, minimum: number, maximum: number): number {
  if (!Number.isSafeInteger(value) || (value as number) < minimum || (value as number) > maximum) {
    invalid();
  }
  return value as number;
}
function choices(value: unknown): string[] {
  if (!Array.isArray(value) || value.length < 2 || value.length > limits.options) invalid();
  const result = value.map((item) => textValue(item, limits.option));
  if (new Set(result.map((item) => item.trim().toLowerCase())).size !== result.length) invalid();
  return result;
}
function answerIndexes(value: unknown, optionCount: number): number[] {
  if (!Array.isArray(value) || value.length < 2) invalid();
  const result = value.map((item) => integer(item, 0, optionCount - 1));
  if (new Set(result).size !== result.length) invalid();
  return result;
}

function splitQuestion(
  raw: unknown,
  isTest: boolean,
): { publicQuestion: PublicQuestion; key: QuestionKey } {
  if (!record(raw)) invalid();
  const type = raw.type;
  const question = textValue(raw.question, limits.question);
  if (type === 'Text') {
    if (!exact(raw, ['type', 'question'])) invalid();
    return { publicQuestion: { type, question }, key: { type } };
  }
  if (type !== 'Single' && type !== 'Multiple') invalid();
  const gradingField = type === 'Single' ? 'correctAnswer' : 'correctAnswers';
  if (!exact(raw, isTest
    ? ['type', 'question', 'options', gradingField]
    : ['type', 'question', 'options'])) invalid();
  const options = choices(raw.options);
  const publicQuestion: PublicQuestion = { type, question, options };
  if (!isTest) return { publicQuestion, key: { type } };
  return type === 'Single'
    ? { publicQuestion, key: { type, correctAnswer: integer(raw.correctAnswer, 0, options.length - 1) } }
    : { publicQuestion, key: { type, correctAnswers: answerIndexes(raw.correctAnswers, options.length) } };
}

export function validateSurveyDefinition(raw: unknown): ValidatedDefinition {
  if (!record(raw) || !exact(raw, [
    'surveyName', 'surveyDescription', 'deadlineMillis',
    'timeLimitPerQuestion', 'surveyType', 'questions',
  ]) || !Array.isArray(raw.questions) || raw.questions.length < 2 ||
      raw.questions.length > limits.questions) invalid();
  if (Buffer.byteLength(JSON.stringify(raw), 'utf8') > limits.definitionBytes) invalid();
  const surveyType = integer(raw.surveyType, 0, 1) as 0 | 1;
  const questions = raw.questions.map((question) => splitQuestion(question, surveyType === 1));
  return {
    publicDefinition: {
      surveyName: textValue(raw.surveyName, limits.surveyName),
      surveyDescription: textValue(raw.surveyDescription, limits.description, true),
      deadlineMillis: integer(raw.deadlineMillis, 0, limits.deadline),
      timeLimitPerQuestion: integer(raw.timeLimitPerQuestion, 0, 86_400),
      surveyType,
      questions: questions.map(({ publicQuestion }) => publicQuestion),
    },
    questionKeys: questions.map(({ key }) => key),
  };
}

function parseRequest(raw: unknown): { surveyId: string; definition: ValidatedDefinition } {
  if (!record(raw) || !exact(raw, ['action', 'surveyId', 'definition']) ||
      raw.action !== 'create' || typeof raw.surveyId !== 'string' ||
      !/^[A-Za-z0-9_-]{1,128}$/.test(raw.surveyId)) {
    return fail('invalid-argument', 'survey-request-invalid');
  }
  try {
    return { surveyId: raw.surveyId, definition: validateSurveyDefinition(raw.definition) };
  } catch {
    return fail('invalid-argument', 'survey-definition-invalid');
  }
}

async function runFirestoreTransaction<T>(
  work: (transaction: PublicationTransaction) => Promise<T>,
): Promise<T> {
  const firestore = getFirestore();
  return firestore.runTransaction((transaction) => work({
    get: async (path) => {
      const snapshot = await transaction.get(firestore.doc(path));
      return snapshot.exists ? snapshot.data() : undefined;
    },
    create: (path, data) => transaction.create(firestore.doc(path), data),
  }));
}

async function authorizedCompany(transaction: PublicationTransaction, uid: string): Promise<string> {
  const [profile, deletionLock] = await Promise.all([
    transaction.get(`users/${uid}`),
    transaction.get(`accountDeletionLocks/${uid}`),
  ]);
  if (!profile || deletionLock) fail('failed-precondition', 'survey-author-account-unavailable');
  const companyId = typeof profile.companyId === 'string' ? profile.companyId : '';
  if (!/^[A-Za-z0-9_-]{1,128}$/.test(companyId)) {
    fail('failed-precondition', 'survey-author-membership-unavailable');
  }
  const [member, company, ban] = await Promise.all([
    transaction.get(`memberDirectory/${uid}`),
    transaction.get(`companies/${companyId}`),
    transaction.get(`companies/${companyId}/bans/${uid}`),
  ]);
  if (!member || !company || member.companyId !== companyId ||
      member.role !== profile.role || member.membership !== profile.membership) {
    fail('failed-precondition', 'survey-author-membership-unavailable');
  }
  if ('deletionScheduledFor' in company) fail('failed-precondition', 'company-closing');
  if (ban) fail('permission-denied', 'company-banned');
  if (profile.membership !== 'active') fail('permission-denied', 'company-membership-inactive');
  if (!['admin', 'moderator', 'superadmin'].includes(String(profile.role))) {
    fail('permission-denied', 'survey-author-role-required');
  }
  return companyId;
}

/** Creates one immutable canonical public/private survey pair. */
export async function saveSurveyDefinitionForUser(
  uid: string,
  rawRequest: unknown,
  dependencies: SurveyPublicationDependencies = {},
): Promise<SaveSurveyDefinitionResult> {
  if (!uid || uid.length > 128 || uid.includes('/')) {
    fail('failed-precondition', 'survey-author-account-unavailable');
  }
  const request = parseRequest(rawRequest);
  const nowMillis = (dependencies.nowMillis ?? Date.now)();
  if (!Number.isSafeInteger(nowMillis) || nowMillis < 0) throw new Error('Invalid server clock.');
  try {
    const getUser = dependencies.getAuthUser ?? (async (userId: string) => {
      const user = await getAuth().getUser(userId);
      return { emailVerified: user.emailVerified, disabled: user.disabled };
    });
    const user = await getUser(uid);
    if (!user.emailVerified || user.disabled) throw new Error();
  } catch {
    fail('failed-precondition', 'survey-author-account-unavailable');
  }
  const definition = request.definition.publicDefinition;
  if (definition.deadlineMillis <= nowMillis) fail('invalid-argument', 'survey-deadline-invalid');

  const runTransaction = dependencies.runTransaction ?? runFirestoreTransaction;
  return runTransaction(async (transaction) => {
    const companyId = await authorizedCompany(transaction, uid);
    const publicPath = `surveys/${request.surveyId}`;
    const privatePath = `surveyAnswerKeys/${request.surveyId}`;
    const [survey, answerKey] = await Promise.all([
      transaction.get(publicPath),
      transaction.get(privatePath),
    ]);
    if (survey || answerKey) fail('already-exists', 'survey-id-conflict');
    transaction.create(publicPath, {
      surveyName: definition.surveyName,
      surveyDescription: definition.surveyDescription,
      timeCreated: Timestamp.fromMillis(nowMillis),
      questions: definition.questions,
      id: request.surveyId,
      participants: [],
      deadline: Timestamp.fromMillis(definition.deadlineMillis),
      timeLimitPerQuestion: definition.timeLimitPerQuestion,
      surveyType: definition.surveyType,
      companyId,
      createdBy: uid,
      responsesRevision: 0,
    });
    transaction.create(privatePath, {
      schemaVersion: 1,
      surveyId: request.surveyId,
      companyId,
      questionKeys: request.definition.questionKeys,
    });
    // A test and a survey are the same document with different consequences, so
    // the log distinguishes them. The marked answers are written in the same
    // transaction as the questions and cannot be edited afterwards, so this one
    // event covers "created" and "answers marked" both.
    writeCompanyActivity(transaction, {
      id: `survey-created-${request.surveyId}`,
      companyId,
      action: 'survey.created',
      actorUid: uid,
      entity: {
        // 1 is a graded test, 0 a plain survey — the same encoding the
        // document itself stores.
        type: definition.surveyType === 1 ? 'test' : 'survey',
        id: request.surveyId,
        title: activityTitle(definition.surveyName),
      },
      occurredAt: Timestamp.fromMillis(nowMillis),
    });
    return { surveyId: request.surveyId };
  });
}
