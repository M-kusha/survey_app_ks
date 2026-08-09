#!/usr/bin/env node
'use strict';

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const EXPECTED_PROJECT = 'echomeet-app';
const MAX_BATCH_WRITES = 450;

function usage() {
  return [
    'Usage:',
    `  node scripts/backfill_appointment_participants.js --project ${EXPECTED_PROJECT}`,
    `  node scripts/backfill_appointment_participants.js --project ${EXPECTED_PROJECT} --apply`,
    '',
    'The first command is read-only. Writes require the exact project and',
    'the explicit --apply flag. Existing participantUserIds values are never',
    'overwritten; inconsistencies are reported as conflicts.',
  ].join('\n');
}

function parseArgs(argv) {
  let apply = false;
  let help = false;
  let project;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--help' || argument === '-h') {
      help = true;
    } else if (argument === '--apply') {
      if (apply) throw new Error('--apply was supplied more than once.');
      apply = true;
    } else if (argument === '--project') {
      if (project !== undefined) {
        throw new Error('--project was supplied more than once.');
      }
      project = argv[index + 1];
      if (!project || project.startsWith('--')) {
        throw new Error('--project requires a value.');
      }
      index += 1;
    } else {
      throw new Error(`Unknown argument: ${argument}`);
    }
  }

  if (!help && project !== EXPECTED_PROJECT) {
    throw new Error(`Refusing to run without --project ${EXPECTED_PROJECT}.`);
  }
  if (!help && process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'Unset FIRESTORE_EMULATOR_HOST; an emulator run cannot validate the release backfill.',
    );
  }
  return { apply, help, project };
}

function sameStrings(left, right) {
  return (
    left.length === right.length &&
    left.every((value, index) => value === right[index])
  );
}

function validateExisting(value, expected) {
  if (!Array.isArray(value) || value.some((item) => typeof item !== 'string')) {
    return 'participantUserIds exists but is not a string array';
  }
  const normalized = [...new Set(value)].sort();
  if (normalized.length !== value.length) {
    return 'participantUserIds contains duplicate values';
  }
  if (!sameStrings(normalized, expected)) {
    return `participantUserIds differs from ${expected.length} participant user(s)`;
  }
  return null;
}

async function expectedParticipants(appointment) {
  const votes = await appointment.ref.collection('participants').get();
  const users = new Set();
  const conflicts = [];

  for (const vote of votes.docs) {
    const userId = vote.get('userId');
    if (typeof userId !== 'string' || userId.length === 0) {
      conflicts.push({
        path: vote.ref.path,
        reason: 'participant vote has no valid userId',
      });
    } else {
      users.add(userId);
    }
  }

  return { conflicts, users: [...users].sort(), voteCount: votes.size };
}

async function buildPlan(db) {
  const appointments = await db.collection('appointments').get();
  const candidates = [];
  const conflicts = [];
  let exact = 0;
  let votes = 0;

  for (const appointment of appointments.docs) {
    const expected = await expectedParticipants(appointment);
    votes += expected.voteCount;
    conflicts.push(...expected.conflicts);

    const data = appointment.data();
    if (Object.prototype.hasOwnProperty.call(data, 'participantUserIds')) {
      const reason = validateExisting(data.participantUserIds, expected.users);
      if (reason) conflicts.push({ path: appointment.ref.path, reason });
      else exact += 1;
      continue;
    }

    candidates.push({
      path: appointment.ref.path,
      ref: appointment.ref,
      updateTime: appointment.updateTime,
      users: expected.users,
    });
  }

  return { candidates, conflicts, exact, scanned: appointments.size, votes };
}

function printPlan(plan) {
  console.log(
    [
      `appointments=${plan.scanned}`,
      `votes=${plan.votes}`,
      `exact=${plan.exact}`,
      `backfill=${plan.candidates.length}`,
      `conflicts=${plan.conflicts.length}`,
    ].join(' '),
  );
  for (const item of plan.candidates) {
    console.log(`BACKFILL ${item.path} voters=${item.users.length}`);
  }
  for (const conflict of plan.conflicts) {
    console.error(`CONFLICT ${conflict.path}: ${conflict.reason}`);
  }
}

async function revalidate(db, candidates) {
  const ready = [];
  const conflicts = [];
  let completedElsewhere = 0;

  for (const candidate of candidates) {
    const current = await candidate.ref.get();
    if (!current.exists) {
      conflicts.push({ path: candidate.path, reason: 'appointment disappeared' });
      continue;
    }

    const expected = await expectedParticipants(current);
    conflicts.push(...expected.conflicts);
    const data = current.data();
    if (Object.prototype.hasOwnProperty.call(data, 'participantUserIds')) {
      const reason = validateExisting(data.participantUserIds, expected.users);
      if (reason) conflicts.push({ path: candidate.path, reason });
      else completedElsewhere += 1;
      continue;
    }

    ready.push({
      ...candidate,
      updateTime: current.updateTime,
      users: expected.users,
    });
  }

  return { completedElsewhere, conflicts, ready };
}

async function applyPlan(db, candidates) {
  let written = 0;
  for (let offset = 0; offset < candidates.length; offset += MAX_BATCH_WRITES) {
    const chunk = candidates.slice(offset, offset + MAX_BATCH_WRITES);
    const batch = db.batch();
    for (const candidate of chunk) {
      batch.update(
        candidate.ref,
        { participantUserIds: candidate.users },
        { lastUpdateTime: candidate.updateTime },
      );
    }
    await batch.commit();
    written += chunk.length;
    console.log(`Committed ${written}/${candidates.length} appointments.`);
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
    'appointment-participant-backfill',
  );
  try {
    console.log(
      `Project=${options.project} mode=${options.apply ? 'APPLY' : 'DRY RUN'}`,
    );
    const db = getFirestore(app);
    const plan = await buildPlan(db);
    printPlan(plan);
    if (plan.conflicts.length > 0) {
      throw new Error('Preflight conflicts found; no writes were attempted.');
    }
    if (!options.apply) {
      console.log('Dry run complete; no writes were attempted.');
      return;
    }

    const checked = await revalidate(db, plan.candidates);
    for (const conflict of checked.conflicts) {
      console.error(`CONFLICT ${conflict.path}: ${conflict.reason}`);
    }
    if (checked.conflicts.length > 0) {
      throw new Error('Revalidation conflicts found; no writes were attempted.');
    }
    console.log(`Completed concurrently: ${checked.completedElsewhere}`);
    await applyPlan(db, checked.ready);
    console.log(`Apply complete; backfilled ${checked.ready.length} appointments.`);
  } finally {
    await deleteApp(app);
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error instanceof Error ? error.message : String(error));
    console.error(usage());
    process.exitCode = 1;
  });
}

module.exports = {
  EXPECTED_PROJECT,
  MAX_BATCH_WRITES,
  parseArgs,
  validateExisting,
};
