'use strict';

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const REQUIRED_PROJECT_ID = 'echomeet-app';
const MAX_BATCH_WRITES = 450;
const DIRECTORY_KEYS = ['joinPolicy', 'name'];

function usage() {
  return [
    'Usage:',
    '  node scripts/backfill_company_directory.js --project echomeet-app',
    '  node scripts/backfill_company_directory.js --project echomeet-app --apply',
    '',
    'The first command is read-only. Writes require both the exact project and',
    'the explicit --apply flag.',
  ].join('\n');
}

function parseArgs(argv) {
  let apply = false;
  let projectId;
  let help = false;

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];

    if (argument === '--help' || argument === '-h') {
      help = true;
      continue;
    }

    if (argument === '--apply') {
      if (apply) throw new Error('The --apply flag was provided more than once.');
      apply = true;
      continue;
    }

    if (argument === '--project') {
      if (projectId !== undefined) {
        throw new Error('The --project flag was provided more than once.');
      }

      projectId = argv[index + 1];
      if (!projectId || projectId.startsWith('--')) {
        throw new Error('--project requires a value.');
      }
      index += 1;
      continue;
    }

    throw new Error(`Unknown argument: ${argument}`);
  }

  if (help) return { help: true, apply: false, projectId: undefined };

  if (projectId !== REQUIRED_PROJECT_ID) {
    throw new Error(
      `Refusing to run: pass the exact arguments --project ${REQUIRED_PROJECT_ID}.`,
    );
  }

  return { help: false, apply, projectId };
}

function companyProjection(companyId, data) {
  const name = data.name;
  if (
    typeof name !== 'string' ||
    name.trim().length === 0 ||
    Array.from(name).length > 120
  ) {
    throw new Error(
      `companies/${companyId} has an invalid name; expected 1-120 non-blank characters.`,
    );
  }

  const hasJoinPolicy = Object.prototype.hasOwnProperty.call(data, 'joinPolicy');
  const joinPolicy = hasJoinPolicy ? data.joinPolicy : 'open';
  if (joinPolicy !== 'open' && joinPolicy !== 'approval') {
    throw new Error(
      `companies/${companyId} has an unsupported joinPolicy.`,
    );
  }

  return { name, joinPolicy };
}

function directoryConflict(actual, expected) {
  const keys = Object.keys(actual).sort();
  if (
    keys.length !== DIRECTORY_KEYS.length ||
    keys.some((key, index) => key !== DIRECTORY_KEYS[index])
  ) {
    return `fields are [${keys.join(', ')}], expected exactly [${DIRECTORY_KEYS.join(', ')}]`;
  }

  if (actual.name !== expected.name) return 'name differs from companies source';
  if (actual.joinPolicy !== expected.joinPolicy) {
    return 'joinPolicy differs from companies source';
  }

  return null;
}

async function buildPlan(db) {
  const [companiesSnapshot, directorySnapshot] = await Promise.all([
    db.collection('companies').get(),
    db.collection('companyDirectory').get(),
  ]);

  const sourceIds = new Set();
  const expectedById = new Map();
  const directoryById = new Map();
  const conflicts = [];
  let exactCount = 0;

  for (const document of companiesSnapshot.docs) {
    sourceIds.add(document.id);
    try {
      expectedById.set(
        document.id,
        companyProjection(document.id, document.data()),
      );
    } catch (error) {
      conflicts.push({
        id: document.id,
        reason: error instanceof Error ? error.message : String(error),
      });
    }
  }

  for (const document of directorySnapshot.docs) {
    directoryById.set(document.id, document.data());

    if (!sourceIds.has(document.id)) {
      conflicts.push({
        id: document.id,
        reason: 'companyDirectory document has no matching companies source',
      });
      continue;
    }

    const expected = expectedById.get(document.id);
    if (!expected) continue;

    const reason = directoryConflict(document.data(), expected);
    if (reason) {
      conflicts.push({ id: document.id, reason });
    } else {
      exactCount += 1;
    }
  }

  const creates = [];
  for (const [id, data] of expectedById.entries()) {
    if (!directoryById.has(id)) creates.push({ id, data });
  }

  creates.sort((left, right) => left.id.localeCompare(right.id));
  conflicts.sort((left, right) => left.id.localeCompare(right.id));

  return {
    sourceCount: companiesSnapshot.size,
    directoryCount: directorySnapshot.size,
    exactCount,
    creates,
    conflicts,
  };
}

function printPlan(plan) {
  console.log(
    [
      `companies=${plan.sourceCount}`,
      `companyDirectory=${plan.directoryCount}`,
      `exact=${plan.exactCount}`,
      `create=${plan.creates.length}`,
      `conflicts=${plan.conflicts.length}`,
    ].join(' '),
  );

  for (const item of plan.creates) {
    console.log(
      `CREATE companyDirectory/${item.id} ${JSON.stringify(item.data)}`,
    );
  }

  for (const conflict of plan.conflicts) {
    console.error(`CONFLICT ${conflict.id}: ${conflict.reason}`);
  }
}

async function applyPlan(db, creates) {
  let written = 0;

  for (let offset = 0; offset < creates.length; offset += MAX_BATCH_WRITES) {
    const chunk = creates.slice(offset, offset + MAX_BATCH_WRITES);
    const batch = db.batch();

    for (const item of chunk) {
      const reference = db.collection('companyDirectory').doc(item.id);
      // `create` is intentional: a target created after validation must make the
      // batch fail instead of being overwritten.
      batch.create(reference, item.data);
    }

    await batch.commit();
    written += chunk.length;
    console.log(`Committed ${written}/${creates.length} creates.`);
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(usage());
    return;
  }

  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new Error(
      'Unset FIRESTORE_EMULATOR_HOST; an emulator dry-run cannot validate the release backfill.',
    );
  }

  const app = initializeApp(
    {
      credential: applicationDefault(),
      projectId: options.projectId,
    },
    'company-directory-backfill',
  );

  try {
    console.log(
      `Project=${options.projectId} mode=${options.apply ? 'APPLY' : 'DRY RUN'}`,
    );

    const db = getFirestore(app);
    const plan = await buildPlan(db);
    printPlan(plan);

    if (plan.conflicts.length > 0) {
      throw new Error('Conflict validation failed; no writes were attempted.');
    }

    if (!options.apply) {
      console.log('Dry run complete; no writes were attempted.');
      return;
    }

    if (plan.creates.length === 0) {
      console.log('Nothing to create.');
      return;
    }

    await applyPlan(db, plan.creates);
    console.log(`Apply complete; created ${plan.creates.length} documents.`);
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
  MAX_BATCH_WRITES,
  REQUIRED_PROJECT_ID,
  companyProjection,
  directoryConflict,
  parseArgs,
};
