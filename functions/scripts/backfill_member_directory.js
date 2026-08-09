'use strict';

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const REQUIRED_PROJECT_ID = 'echomeet-app';
const MAX_BATCH_WRITES = 450;
const ALLOWED_ROLES = new Set(['user', 'admin', 'moderator', 'superadmin']);
const ALLOWED_MEMBERSHIPS = new Set(['active', 'pending']);

function usage() {
  return [
    'Usage:',
    '  node scripts/backfill_member_directory.js --project echomeet-app',
    '  node scripts/backfill_member_directory.js --project echomeet-app --apply',
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

function memberProjection(userId, data, companyIds) {
  const companyId = data.companyId;
  if (companyId === '') return null;
  if (typeof companyId !== 'string' || !companyIds.has(companyId)) {
    throw new Error(
      `users/${userId} references a missing or invalid companyId.`,
    );
  }

  const fullName = data.fullName;
  if (
    typeof fullName !== 'string' ||
    fullName.trim().length === 0 ||
    Array.from(fullName).length > 120
  ) {
    throw new Error(
      `users/${userId} has an invalid fullName; expected 1-120 non-blank characters.`,
    );
  }

  const role = data.role;
  if (!ALLOWED_ROLES.has(role)) {
    throw new Error(`users/${userId} has an unsupported role.`);
  }

  const membership = Object.prototype.hasOwnProperty.call(data, 'membership')
    ? data.membership
    : 'active';
  if (!ALLOWED_MEMBERSHIPS.has(membership)) {
    throw new Error(`users/${userId} has an unsupported membership.`);
  }

  const projection = { fullName, companyId, role, membership };
  if (Object.prototype.hasOwnProperty.call(data, 'profileImage')) {
    if (typeof data.profileImage !== 'string') {
      throw new Error(`users/${userId} has a non-string profileImage.`);
    }
    projection.profileImage = data.profileImage;
  }
  if (Object.prototype.hasOwnProperty.call(data, 'profileImageRevision')) {
    if (
      !Number.isInteger(data.profileImageRevision) ||
      data.profileImageRevision < 0 ||
      data.profileImageRevision > 2147483647
    ) {
      throw new Error(`users/${userId} has an invalid profileImageRevision.`);
    }
    projection.profileImageRevision = data.profileImageRevision;
  }
  return projection;
}

function directoryConflict(actual, expected) {
  const actualKeys = Object.keys(actual).sort();
  const expectedKeys = Object.keys(expected).sort();
  if (
    actualKeys.length !== expectedKeys.length ||
    actualKeys.some((key, index) => key !== expectedKeys[index])
  ) {
    return `fields are [${actualKeys.join(', ')}], expected exactly [${expectedKeys.join(', ')}]`;
  }
  for (const key of expectedKeys) {
    if (actual[key] !== expected[key]) return `${key} differs from users source`;
  }
  return null;
}

async function buildPlan(db) {
  const [usersSnapshot, companiesSnapshot, directorySnapshot] =
    await Promise.all([
      db.collection('users').get(),
      db.collection('companies').get(),
      db.collection('memberDirectory').get(),
    ]);

  const companyIds = new Set(companiesSnapshot.docs.map((doc) => doc.id));
  const sourceIds = new Set(usersSnapshot.docs.map((doc) => doc.id));
  const expectedById = new Map();
  const directoryById = new Map();
  const conflicts = [];
  let excludedCount = 0;
  let exactCount = 0;

  for (const document of usersSnapshot.docs) {
    try {
      const projection = memberProjection(
        document.id,
        document.data(),
        companyIds,
      );
      if (projection === null) {
        excludedCount += 1;
      } else {
        expectedById.set(document.id, projection);
      }
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
        reason: 'memberDirectory document has no matching users source',
      });
      continue;
    }

    const expected = expectedById.get(document.id);
    if (!expected) {
      conflicts.push({
        id: document.id,
        reason: 'memberDirectory document belongs to a user with no valid company',
      });
      continue;
    }

    const reason = directoryConflict(document.data(), expected);
    if (reason) conflicts.push({ id: document.id, reason });
    else exactCount += 1;
  }

  const creates = [];
  for (const [id, data] of expectedById.entries()) {
    if (!directoryById.has(id)) creates.push({ id, data });
  }
  creates.sort((left, right) => left.id.localeCompare(right.id));
  conflicts.sort((left, right) => left.id.localeCompare(right.id));

  return {
    userCount: usersSnapshot.size,
    companyCount: companiesSnapshot.size,
    eligibleCount: expectedById.size,
    excludedCount,
    directoryCount: directorySnapshot.size,
    exactCount,
    creates,
    conflicts,
  };
}

function printPlan(plan) {
  console.log(
    [
      `users=${plan.userCount}`,
      `companies=${plan.companyCount}`,
      `eligible=${plan.eligibleCount}`,
      `noCompany=${plan.excludedCount}`,
      `memberDirectory=${plan.directoryCount}`,
      `exact=${plan.exactCount}`,
      `create=${plan.creates.length}`,
      `conflicts=${plan.conflicts.length}`,
    ].join(' '),
  );
  for (const item of plan.creates) {
    console.log(`CREATE memberDirectory/${item.id} ${JSON.stringify(item.data)}`);
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
      batch.create(db.collection('memberDirectory').doc(item.id), item.data);
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
    { credential: applicationDefault(), projectId: options.projectId },
    'member-directory-backfill',
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
  directoryConflict,
  memberProjection,
  parseArgs,
};
