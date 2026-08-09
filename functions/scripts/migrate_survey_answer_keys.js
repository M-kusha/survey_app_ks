#!/usr/bin/env node
'use strict';

const { isDeepStrictEqual } = require('node:util');
const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const EXPECTED_PROJECT = 'echomeet-app';
const WRITE_BATCH_LIMIT = 450;
const MAX_ACTIONS_PER_BATCH = 200;
const PHASES = new Set(['prepare', 'sanitize']);

class UsageError extends Error {}

function usage() {
  return `Usage:
  node scripts/migrate_survey_answer_keys.js \\
    --project ${EXPECTED_PROJECT} --phase <prepare|sanitize> [--apply]

Safety:
  * The default is a read-only dry run.
  * Writes require the exact project, an explicit phase, and --apply. Every
    mode refuses a Firestore emulator so a release dry-run cannot validate an
    empty local database.
  * prepare creates immutable private keys but does not change public surveys.
  * sanitize removes public answer fields only after an exact private key exists.
  * Validation conflicts abort the entire preflight before the first write.
  * Writes use create/update-time preconditions in batches of at most
    ${WRITE_BATCH_LIMIT}. Rerunning either phase is safe.`;
}

function parseArgs(argv) {
  const options = { apply: false, help: false, phase: null, project: null };

  function valueAfter(index, flag) {
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new UsageError(`${flag} requires a value.`);
    }
    return value;
  }

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--help' || argument === '-h') {
      options.help = true;
    } else if (argument === '--apply') {
      if (options.apply) throw new UsageError('--apply was supplied twice.');
      options.apply = true;
    } else if (argument === '--project') {
      if (options.project !== null) {
        throw new UsageError('--project was supplied twice.');
      }
      options.project = valueAfter(index, '--project');
      index += 1;
    } else if (argument === '--phase') {
      if (options.phase !== null) {
        throw new UsageError('--phase was supplied twice.');
      }
      options.phase = valueAfter(index, '--phase');
      index += 1;
    } else {
      throw new UsageError(`Unknown argument: ${argument}`);
    }
  }

  if (options.help) return options;
  if (options.project !== EXPECTED_PROJECT) {
    throw new UsageError(
      `Refusing to continue: --project must be exactly "${EXPECTED_PROJECT}".`,
    );
  }
  if (!PHASES.has(options.phase)) {
    throw new UsageError('--phase must be exactly "prepare" or "sanitize".');
  }
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new UsageError(
      'Refusing while FIRESTORE_EMULATOR_HOST is set.',
    );
  }
  return options;
}

function isRecord(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function inspectQuestions(surveyId, survey) {
  if (!Array.isArray(survey.questions) || survey.questions.length === 0) {
    throw new Error(`surveys/${surveyId} has no valid questions array.`);
  }
  if (survey.questions.length > 100) {
    throw new Error(`surveys/${surveyId} has more than 100 questions.`);
  }
  if (typeof survey.companyId !== 'string' || survey.companyId.length === 0) {
    throw new Error(`surveys/${surveyId} has no companyId.`);
  }

  const isTest = survey.surveyType === 1;
  const publicQuestions = [];
  const derivedKeys = [];
  let hasEmbeddedKeys = false;
  let completeDerivedKey = true;

  survey.questions.forEach((rawQuestion, index) => {
    if (!isRecord(rawQuestion)) {
      throw new Error(`surveys/${surveyId} question ${index} is not a map.`);
    }

    const question = { ...rawQuestion };
    const type = question.type;
    const options = Array.isArray(question.options) ? question.options : [];
    const hadSingle = Object.hasOwn(question, 'correctAnswer');
    const hadMultiple = Object.hasOwn(question, 'correctAnswers');
    hasEmbeddedKeys ||= hadSingle || hadMultiple;
    delete question.correctAnswer;
    delete question.correctAnswers;
    publicQuestions.push(question);

    if (type === 'Single') {
      const answer = rawQuestion.correctAnswer;
      if (!isTest) {
        derivedKeys.push({ type: 'Single' });
        return;
      }
      if (
        !Number.isInteger(answer) ||
        answer < 0 ||
        answer >= options.length
      ) {
        if (isTest) completeDerivedKey = false;
        derivedKeys.push({ type: 'Single' });
      } else {
        derivedKeys.push({ type: 'Single', correctAnswer: answer });
      }
      return;
    }

    if (type === 'Multiple') {
      const answers = rawQuestion.correctAnswers;
      if (!isTest) {
        derivedKeys.push({ type: 'Multiple' });
        return;
      }
      const valid =
        Array.isArray(answers) &&
        (!isTest || answers.length >= 2) &&
        answers.every(
          (answer) =>
            Number.isInteger(answer) &&
            answer >= 0 &&
            answer < options.length,
        ) &&
        new Set(answers).size === answers.length;
      if (!valid) {
        if (isTest) completeDerivedKey = false;
        derivedKeys.push({ type: 'Multiple', correctAnswers: [] });
      } else {
        derivedKeys.push({ type: 'Multiple', correctAnswers: [...answers] });
      }
      return;
    }

    if (type === 'Text') {
      derivedKeys.push({ type: 'Text' });
      return;
    }

    throw new Error(
      `surveys/${surveyId} question ${index} has unsupported type ${String(type)}.`,
    );
  });

  return {
    completeDerivedKey,
    hasEmbeddedKeys,
    privateDocument: {
      schemaVersion: 1,
      surveyId,
      companyId: survey.companyId,
      questionKeys: derivedKeys,
    },
    publicQuestions,
  };
}

function validateStoredKey(surveyId, survey, publicQuestions, stored) {
  if (
    !isRecord(stored) ||
    stored.schemaVersion !== 1 ||
    stored.surveyId !== surveyId ||
    stored.companyId !== survey.companyId ||
    !Array.isArray(stored.questionKeys) ||
    stored.questionKeys.length !== publicQuestions.length ||
    Object.keys(stored).sort().join(',') !==
      'companyId,questionKeys,schemaVersion,surveyId'
  ) {
    return 'private answer-key envelope does not exactly match the survey';
  }

  for (let index = 0; index < publicQuestions.length; index += 1) {
    const question = publicQuestions[index];
    const key = stored.questionKeys[index];
    if (!isRecord(key) || key.type !== question.type) {
      return `private key ${index} has the wrong type`;
    }
    const options = Array.isArray(question.options) ? question.options : [];
    if (survey.surveyType !== 1) {
      if (Object.keys(key).sort().join(',') !== 'type') {
        return `private survey key ${index} contains grading material`;
      }
      continue;
    }
    if (
      question.type === 'Single' &&
      (Object.keys(key).sort().join(',') !== 'correctAnswer,type' ||
        !Number.isInteger(key.correctAnswer) ||
        key.correctAnswer < 0 ||
        key.correctAnswer >= options.length)
    ) {
      return `private key ${index} has an invalid single answer`;
    }
    if (question.type === 'Multiple') {
      const answers = key.correctAnswers;
      if (
        Object.keys(key).sort().join(',') !== 'correctAnswers,type' ||
        !Array.isArray(answers) ||
        answers.length < 2 ||
        new Set(answers).size !== answers.length ||
        answers.some(
          (answer) =>
            !Number.isInteger(answer) ||
            answer < 0 ||
            answer >= options.length,
        )
      ) {
        return `private key ${index} has invalid multiple answers`;
      }
    }
    if (
      question.type === 'Text' &&
      Object.keys(key).sort().join(',') !== 'type'
    ) {
      return `private text key ${index} contains unexpected fields`;
    }
  }
  return null;
}

async function buildPlan(db, phase) {
  const [surveysSnapshot, keysSnapshot] = await Promise.all([
    db.collection('surveys').get(),
    db.collection('surveyAnswerKeys').get(),
  ]);
  const storedById = new Map(keysSnapshot.docs.map((doc) => [doc.id, doc]));
  const surveyIds = new Set(surveysSnapshot.docs.map((doc) => doc.id));
  const actions = [];
  const conflicts = [];
  let exact = 0;

  for (const key of keysSnapshot.docs) {
    if (!surveyIds.has(key.id)) {
      conflicts.push({ id: key.id, reason: 'private key has no survey source' });
    }
  }

  for (const surveyDocument of surveysSnapshot.docs) {
    const id = surveyDocument.id;
    try {
      const survey = surveyDocument.data();
      const inspection = inspectQuestions(id, survey);
      const storedDocument = storedById.get(id);
      const stored = storedDocument?.data();

      if (stored) {
        const invalid = validateStoredKey(
          id,
          survey,
          inspection.publicQuestions,
          stored,
        );
        if (invalid) throw new Error(invalid);

        if (
          inspection.hasEmbeddedKeys &&
          (!inspection.completeDerivedKey ||
            !isDeepStrictEqual(stored, inspection.privateDocument))
        ) {
          throw new Error('public and private grading keys disagree');
        }
      }

      if (phase === 'prepare') {
        if (stored) {
          exact += 1;
        } else if (!inspection.completeDerivedKey) {
          throw new Error('public test no longer contains a complete answer key');
        } else {
          actions.push({
            kind: 'CREATE_KEY',
            id,
            data: inspection.privateDocument,
            sourceQuestions: survey.questions,
            updateTime: surveyDocument.updateTime,
          });
        }
        continue;
      }

      if (!stored) throw new Error('private answer key is missing');
      if (inspection.hasEmbeddedKeys) {
        actions.push({
          kind: 'SANITIZE_SURVEY',
          id,
          questions: inspection.publicQuestions,
          updateTime: surveyDocument.updateTime,
        });
      } else {
        exact += 1;
      }
    } catch (error) {
      conflicts.push({
        id,
        reason: error instanceof Error ? error.message : String(error),
      });
    }
  }

  actions.sort((left, right) => left.id.localeCompare(right.id));
  conflicts.sort((left, right) => left.id.localeCompare(right.id));
  return {
    actions,
    conflicts,
    exact,
    keys: keysSnapshot.size,
    surveys: surveysSnapshot.size,
  };
}

function printPlan(plan, phase) {
  console.log(
    `phase=${phase} surveys=${plan.surveys} privateKeys=${plan.keys} ` +
      `exact=${plan.exact} actions=${plan.actions.length} ` +
      `conflicts=${plan.conflicts.length}`,
  );
  for (const action of plan.actions) {
    console.log(`${action.kind} ${action.id}`);
  }
  for (const conflict of plan.conflicts) {
    console.error(`CONFLICT ${conflict.id}: ${conflict.reason}`);
  }
}

async function applyPlan(db, actions) {
  let committed = 0;
  for (let offset = 0; offset < actions.length; offset += MAX_ACTIONS_PER_BATCH) {
    const chunk = actions.slice(offset, offset + MAX_ACTIONS_PER_BATCH);
    const batch = db.batch();
    for (const action of chunk) {
      if (action.kind === 'CREATE_KEY') {
        batch.create(db.collection('surveyAnswerKeys').doc(action.id), action.data);
        // A same-value, preconditioned source update keeps creation atomic with
        // the survey still existing at the exact version that was inspected.
        batch.update(
          db.collection('surveys').doc(action.id),
          { questions: action.sourceQuestions },
          { lastUpdateTime: action.updateTime },
        );
      } else {
        batch.update(
          db.collection('surveys').doc(action.id),
          { questions: action.questions },
          { lastUpdateTime: action.updateTime },
        );
      }
    }
    await batch.commit();
    committed += chunk.length;
    console.log(`Committed ${committed}/${actions.length} actions.`);
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(usage());
    return;
  }

  const app = initializeApp(
    { credential: applicationDefault(), projectId: options.project },
    'survey-answer-key-migration',
  );
  try {
    console.log(
      `Project=${options.project} phase=${options.phase} ` +
        `mode=${options.apply ? 'APPLY' : 'DRY RUN'}`,
    );
    const db = getFirestore(app);
    const plan = await buildPlan(db, options.phase);
    printPlan(plan, options.phase);
    if (plan.conflicts.length > 0) {
      throw new Error('Conflict validation failed; no writes were attempted.');
    }
    if (!options.apply) {
      console.log('Dry run complete; no writes were attempted.');
      return;
    }
    if (plan.actions.length === 0) {
      console.log('Nothing to write.');
      return;
    }
    await applyPlan(db, plan.actions);
    console.log(`Apply complete; ${plan.actions.length} actions committed.`);
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : error);
    console.error(usage());
    process.exitCode = 1;
  });
}

module.exports = {
  EXPECTED_PROJECT,
  WRITE_BATCH_LIMIT,
  inspectQuestions,
  parseArgs,
  validateStoredKey,
};
