#!/usr/bin/env node
'use strict';

const {
  applicationDefault,
  deleteApp,
  initializeApp,
} = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const EXPECTED_PROJECT = 'echomeet-app';
const EXPECTED_BUCKET = 'echomeet-app.firebasestorage.app';
const PHASES = new Set(['access', 'prepare', 'switch']);
const TOKEN_KEY = 'firebaseStorageDownloadTokens';
const RESPONSE_FIELDS = ['imageProfile', 'profileImageUrl'];
const BATCH_LIMIT = 400;

class UsageError extends Error {}

function usage() {
  return `Usage:
  node scripts/migrate_avatar_privacy.js \\
    --project ${EXPECTED_PROJECT} --phase <access|prepare|switch> [--apply]

Safety:
  * The default is a read-only dry run against the exact production project.
  * --apply is accepted only with the exact project and an explicit phase.
  * access synchronizes existing bans into member projections so the two-read
    Storage authorization rule can reject banned viewers.
  * prepare copies legacy objects and strips download tokens. It does not
    change profile/response references.
  * switch atomically changes users/memberDirectory references, precondition-
    updates response snapshots, then deletes legacy objects only after all
    references for that uid have succeeded.
  * Conflicts abort the complete preflight before the first write.
  * All three phases are idempotent; rerun the dry run after any interruption.`;
}

function parseArgs(argv) {
  const options = { apply: false, help: false, phase: null, project: null };
  const takeValue = (index, flag) => {
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new UsageError(`${flag} requires a value.`);
    }
    return value;
  };

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
      options.project = takeValue(index, '--project');
      index += 1;
    } else if (argument === '--phase') {
      if (options.phase !== null) {
        throw new UsageError('--phase was supplied twice.');
      }
      options.phase = takeValue(index, '--phase');
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
    throw new UsageError(
      '--phase must be exactly "access", "prepare", or "switch".',
    );
  }
  if (process.env.FIRESTORE_EMULATOR_HOST || process.env.STORAGE_EMULATOR_HOST) {
    throw new UsageError(
      'Unset FIRESTORE_EMULATOR_HOST and STORAGE_EMULATOR_HOST; the emulators cannot validate this release migration.',
    );
  }
  return options;
}

function canonicalPath(uid) {
  return `profile_images/${uid}/avatar.jpg`;
}

function legacyPath(uid) {
  return `profile_images/${uid}.jpg`;
}

function parseObjectPath(path) {
  let match = /^profile_images\/([^/]{1,128})\/avatar[.]jpg$/.exec(path);
  if (match) return { kind: 'canonical', path, uid: match[1] };
  match = /^profile_images\/([^/]{1,128})[.]jpg$/.exec(path);
  if (match) return { kind: 'legacy', path, uid: match[1] };
  return null;
}

function objectPathFromUrl(value, expectedBucket = EXPECTED_BUCKET) {
  let url;
  try {
    url = new URL(value);
  } catch (_) {
    return null;
  }

  if (url.protocol === 'gs:') {
    if (url.hostname !== expectedBucket) return null;
    return decodeURIComponent(url.pathname.replace(/^\//, ''));
  }
  if (url.protocol !== 'https:' && url.protocol !== 'http:') return null;

  if (url.hostname === 'firebasestorage.googleapis.com') {
    const match = /^\/v\d+\/b\/([^/]+)\/o\/(.+)$/.exec(url.pathname);
    if (!match || decodeURIComponent(match[1]) !== expectedBucket) return null;
    return decodeURIComponent(match[2]);
  }
  if (url.hostname === 'storage.googleapis.com') {
    const match = /^\/([^/]+)\/(.+)$/.exec(url.pathname);
    if (!match || decodeURIComponent(match[1]) !== expectedBucket) return null;
    return decodeURIComponent(match[2]);
  }
  if (url.hostname === `${expectedBucket}.storage.googleapis.com`) {
    return decodeURIComponent(url.pathname.replace(/^\//, ''));
  }
  return null;
}

function classifyReference(value, expectedBucket = EXPECTED_BUCKET) {
  if (typeof value !== 'string' || value.trim() === '') return null;
  const trimmed = value.trim();
  const path = trimmed.startsWith('gs://') || /^https?:\/\//.test(trimmed)
    ? objectPathFromUrl(trimmed, expectedBucket)
    : trimmed;
  return path ? parseObjectPath(path) : null;
}

function hasDownloadToken(metadata) {
  const value = metadata.customMetadata?.[TOKEN_KEY];
  return typeof value === 'string' && value.trim() !== '';
}

function checksumsMatch(left, right) {
  if (left.crc32c && right.crc32c) return left.crc32c === right.crc32c;
  if (left.md5Hash && right.md5Hash) return left.md5Hash === right.md5Hash;
  return false;
}

async function storageInventory(bucket) {
  const [files] = await bucket.getFiles({ prefix: 'profile_images/' });
  const byPath = new Map();
  for (let offset = 0; offset < files.length; offset += 25) {
    const chunk = files.slice(offset, offset + 25);
    const metadata = await Promise.all(chunk.map((file) => file.getMetadata()));
    metadata.forEach(([raw], index) => {
      const parsed = parseObjectPath(chunk[index].name);
      if (!parsed) return;
      byPath.set(chunk[index].name, {
        ...parsed,
        cacheControl: raw.cacheControl,
        contentType: raw.contentType,
        crc32c: raw.crc32c,
        customMetadata: raw.metadata || {},
        generation: String(raw.generation),
        md5Hash: raw.md5Hash,
        metageneration: String(raw.metageneration),
        size: String(raw.size),
      });
    });
  }
  return byPath;
}

function profileProjection(user) {
  const projection = {
    fullName: user.fullName,
    companyId: user.companyId,
    role: user.role,
    membership: user.membership || 'active',
  };
  if (Object.hasOwn(user, 'profileImage')) {
    projection.profileImage = user.profileImage;
  }
  if (Object.hasOwn(user, 'profileImageRevision')) {
    projection.profileImageRevision = user.profileImageRevision;
  }
  return projection;
}

function projectionConflict(user, member) {
  if (user.companyId === '') {
    return member ? 'memberDirectory exists for a user with no company' : null;
  }
  if (!member) return 'memberDirectory is missing';
  const expected = profileProjection(user);
  const actualKeys = Object.keys(member).sort();
  const expectedKeys = Object.keys(expected).sort();
  if (
    actualKeys.length !== expectedKeys.length ||
    actualKeys.some((key, index) => key !== expectedKeys[index])
  ) {
    return 'memberDirectory fields do not exactly match the private projection';
  }
  for (const key of expectedKeys) {
    if (member[key] !== expected[key]) {
      return `memberDirectory.${key} differs from the private profile`;
    }
  }
  return null;
}

async function loadState(db, bucket) {
  const [users, members, responses, bans, objects] = await Promise.all([
    db.collection('users').get(),
    db.collection('memberDirectory').get(),
    db.collectionGroup('participants').get(),
    db.collectionGroup('bans').get(),
    storageInventory(bucket),
  ]);
  return {
    users: new Map(users.docs.map((doc) => [doc.id, doc])),
    members: new Map(members.docs.map((doc) => [doc.id, doc])),
    responses: responses.docs,
    bans: bans.docs,
    objects,
  };
}

function conflict(conflicts, id, reason) {
  conflicts.push({ id, reason });
}

function buildPlan(state, phase) {
  const conflicts = [];
  const avatars = new Map();
  const banActions = [];

  const ensureAvatar = (uid) => {
    if (!avatars.has(uid)) {
      avatars.set(uid, {
        uid,
        user: state.users.get(uid),
        member: state.members.get(uid),
        source: state.objects.get(legacyPath(uid)),
        destination: state.objects.get(canonicalPath(uid)),
        reference: null,
        currentRevision: null,
        targetRevision: null,
        responseUpdates: new Map(),
      });
    }
    return avatars.get(uid);
  };

  if (phase !== 'access') {
    for (const object of state.objects.values()) ensureAvatar(object.uid);

    for (const [uid, userDocument] of state.users) {
    const user = userDocument.data();
    if (!Object.hasOwn(user, 'profileImage') || user.profileImage === '') {
      continue;
    }
    const reference = classifyReference(user.profileImage);
    if (!reference || reference.uid !== uid) {
      conflict(conflicts, `users/${uid}`, 'profileImage is not this user\'s supported Firebase avatar reference');
      continue;
    }
    const avatar = ensureAvatar(uid);
    avatar.reference = reference;
    if (Object.hasOwn(user, 'profileImageRevision')) {
      if (
        !Number.isInteger(user.profileImageRevision) ||
        user.profileImageRevision < 0 ||
        user.profileImageRevision > 2147483647
      ) {
        conflict(conflicts, `users/${uid}`, 'profileImageRevision is invalid');
      } else {
        avatar.currentRevision = user.profileImageRevision;
      }
    }
    const revisionBase = avatar.currentRevision ?? 0;
    avatar.targetRevision =
      reference.kind === 'legacy' || avatar.currentRevision === null
        ? revisionBase + 1
        : revisionBase;
    if (avatar.targetRevision > 2147483647) {
      conflict(conflicts, `users/${uid}`, 'profileImageRevision is exhausted');
    }
    const mismatch = projectionConflict(user, avatar.member?.data());
    if (mismatch) conflict(conflicts, `users/${uid}`, mismatch);
    }

    for (const [uid, avatar] of avatars) {
    if (!avatar.user) {
      conflict(conflicts, legacyPath(uid), 'avatar object has no users source');
      continue;
    }
    const user = avatar.user.data();
    if (!avatar.reference) {
      conflict(conflicts, `users/${uid}`, 'avatar object exists but profileImage is absent');
      continue;
    }
    if (avatar.reference.kind === 'legacy' && !avatar.source && !avatar.destination) {
      conflict(conflicts, `users/${uid}`, 'legacy reference has neither source nor prepared destination object');
    }
    if (avatar.reference.kind === 'canonical' && !avatar.destination) {
      conflict(conflicts, `users/${uid}`, 'canonical reference has no destination object');
    }
    if (
      avatar.source &&
      avatar.destination &&
      avatar.reference.kind === 'legacy' &&
      !checksumsMatch(avatar.source, avatar.destination)
    ) {
      conflict(conflicts, `users/${uid}`, 'legacy and destination object checksums disagree before the profile switch');
    }
    }

    for (const response of state.responses) {
    const data = response.data();
    const uid = data.userId;
    for (const field of RESPONSE_FIELDS) {
      if (!Object.hasOwn(data, field) || data[field] === '') continue;
      if (typeof uid !== 'string' || uid === '') {
        conflict(conflicts, response.ref.path, `${field} has no valid userId owner`);
        continue;
      }
      const reference = classifyReference(data[field]);
      if (!reference || reference.uid !== uid) {
        conflict(conflicts, response.ref.path, `${field} is not the participant's supported Firebase avatar reference`);
        continue;
      }
      const avatar = ensureAvatar(uid);
      const profileReference = avatar.user
        ? classifyReference(avatar.user.data().profileImage)
        : null;
      if (!profileReference || profileReference.uid !== uid) {
        conflict(conflicts, response.ref.path, `${field} has no matching current user avatar reference`);
        continue;
      }
      const responseRevision = data.profileImageRevision;
      if (
        Object.hasOwn(data, 'profileImageRevision') &&
        (!Number.isInteger(responseRevision) ||
          responseRevision < 0 ||
          responseRevision > 2147483647)
      ) {
        conflict(conflicts, response.ref.path, 'profileImageRevision is invalid');
        continue;
      }
      if (
        reference.kind === 'legacy' ||
        responseRevision !== avatar.targetRevision
      ) {
        const current = avatar.responseUpdates.get(response.ref.path) || {
          ref: response.ref,
          updateTime: response.updateTime,
          values: {},
        };
        if (reference.kind === 'legacy') {
          current.values[field] = canonicalPath(uid);
        }
        current.values.profileImageRevision = avatar.targetRevision;
        avatar.responseUpdates.set(response.ref.path, current);
      }
    }
    }

    for (const [uid, avatar] of avatars) {
    if (avatar.responseUpdates.size > 0 && !avatar.destination && !avatar.source) {
      conflict(conflicts, `responses/${uid}`, 'legacy response references have no source or destination avatar object');
    }
    }
  }

  for (const ban of state.bans) {
    const company = ban.ref.parent.parent?.id;
    const uid = ban.id;
    const data = ban.data();
    const user = state.users.get(uid)?.data();
    const member = state.members.get(uid)?.data();
    if (!company || !user || !member || user.companyId !== company || member.companyId !== company) {
      conflict(conflicts, ban.ref.path, 'ban has no matching private/member company projection');
      continue;
    }
    if ((user.membership || 'active') !== (member.membership || 'active')) {
      conflict(conflicts, ban.ref.path, 'private/member membership values disagree');
      continue;
    }
    const hasPrevious = Object.hasOwn(data, 'previousMembership');
    if (hasPrevious) {
      if (!['active', 'pending'].includes(data.previousMembership)) {
        conflict(conflicts, ban.ref.path, 'previousMembership is invalid');
      } else if (user.membership !== 'pending' || member.membership !== 'pending') {
        conflict(conflicts, ban.ref.path, 'prepared ban must have pending membership in both projections');
      }
    } else if (phase === 'access') {
      const previous = user.membership || 'active';
      if (!['active', 'pending'].includes(previous)) {
        conflict(conflicts, ban.ref.path, 'cannot derive a valid previous membership');
      } else {
        banActions.push({ ban, company, uid, previous });
      }
    } else {
      conflict(conflicts, ban.ref.path, 'ban has not passed the prepare phase');
    }
  }

  const avatarActions = [];
  for (const avatar of avatars.values()) {
    if (!avatar.user || !avatar.reference) continue;
    if (phase === 'prepare') {
      avatarActions.push({
        ...avatar,
        copy: Boolean(avatar.source && !avatar.destination),
        revokeDestination: Boolean(
          avatar.destination && hasDownloadToken(avatar.destination),
        ),
        revokeSource: Boolean(avatar.source && hasDownloadToken(avatar.source)),
      });
    } else if (phase === 'switch') {
      if (!avatar.destination) {
        conflict(conflicts, `users/${avatar.uid}`, 'destination object has not passed prepare');
      } else if (hasDownloadToken(avatar.destination)) {
        conflict(conflicts, canonicalPath(avatar.uid), 'destination still has a download token');
      }
      if (avatar.source && hasDownloadToken(avatar.source)) {
        conflict(conflicts, legacyPath(avatar.uid), 'legacy source still has a download token');
      }
      avatarActions.push({
        ...avatar,
        switchProfile: avatar.reference.kind === 'legacy',
        switchRevision: avatar.currentRevision !== avatar.targetRevision,
        deleteSource: Boolean(avatar.source),
      });
    }
  }

  conflicts.sort((left, right) => left.id.localeCompare(right.id));
  avatarActions.sort((left, right) => left.uid.localeCompare(right.uid));
  return { avatarActions, banActions, conflicts, phase };
}

function printPlan(plan) {
  const responseUpdates = plan.avatarActions.reduce(
    (total, avatar) => total + avatar.responseUpdates.size,
    0,
  );
  const pendingAvatarActions = plan.avatarActions.filter((action) =>
    plan.phase === 'prepare'
      ? action.copy || action.revokeSource || action.revokeDestination
      : action.switchProfile || action.switchRevision
        || action.responseUpdates.size > 0 || action.deleteSource,
  ).length;
  console.log(
    [
      `phase=${plan.phase}`,
      `avatars=${plan.avatarActions.length}`,
      `pendingAvatars=${pendingAvatarActions}`,
      `banActions=${plan.banActions.length}`,
      `responseUpdates=${responseUpdates}`,
      `conflicts=${plan.conflicts.length}`,
    ].join(' '),
  );
  for (const action of plan.banActions) {
    console.log(`SYNC_BAN ${action.company}/${action.uid}`);
  }
  for (const action of plan.avatarActions) {
    const labels = plan.phase === 'prepare'
      ? [action.copy && 'COPY', action.revokeSource && 'REVOKE_LEGACY', action.revokeDestination && 'REVOKE_NEW']
      : [action.switchProfile && 'SWITCH_PROFILE', action.switchRevision && 'SET_REVISION', action.responseUpdates.size > 0 && `SWITCH_RESPONSES:${action.responseUpdates.size}`, action.deleteSource && 'DELETE_LEGACY'];
    const work = labels.filter(Boolean).join(',') || 'EXACT';
    console.log(`${work} ${action.uid}`);
  }
  for (const item of plan.conflicts) {
    console.error(`CONFLICT ${item.id}: ${item.reason}`);
  }
}

async function revokeToken(bucket, object) {
  const customMetadata = { ...object.customMetadata };
  delete customMetadata[TOKEN_KEY];
  await bucket.file(object.path).setMetadata(
    { metadata: { ...customMetadata, [TOKEN_KEY]: null } },
    { ifMetagenerationMatch: object.metageneration },
  );
}

async function copyLegacy(bucket, action) {
  const source = action.source;
  const sourceVersion = bucket.file(source.path, {
    generation: source.generation,
  });
  const destination = bucket.file(canonicalPath(action.uid));
  const customMetadata = { ...source.customMetadata };
  delete customMetadata[TOKEN_KEY];
  customMetadata.echomeetAvatarSourceGeneration = source.generation;
  customMetadata.echomeetAvatarMigratedFrom = source.path;

  await sourceVersion.copy(destination, {
    cacheControl: 'private, max-age=3600',
    contentType: source.contentType || 'image/jpeg',
    metadata: customMetadata,
    preconditionOpts: { ifGenerationMatch: 0 },
  });

  const [raw] = await destination.getMetadata();
  const copied = {
    crc32c: raw.crc32c,
    customMetadata: raw.metadata || {},
    md5Hash: raw.md5Hash,
    path: destination.name,
  };
  if (!checksumsMatch(source, copied)) {
    throw new Error(`Checksum verification failed after copying ${source.path}.`);
  }
  if (hasDownloadToken(copied)) {
    await revokeToken(bucket, {
      ...copied,
      metageneration: String(raw.metageneration),
    });
  }
}

async function synchronizeBan(db, action) {
  await db.runTransaction(async (transaction) => {
    const banRef = action.ban.ref;
    const userRef = db.collection('users').doc(action.uid);
    const memberRef = db.collection('memberDirectory').doc(action.uid);
    const [ban, user, member] = await Promise.all([
      transaction.get(banRef),
      transaction.get(userRef),
      transaction.get(memberRef),
    ]);
    if (!ban.exists || !user.exists || !member.exists) {
      throw new Error(`Ban sources changed for ${action.company}/${action.uid}.`);
    }
    if (Object.hasOwn(ban.data(), 'previousMembership')) return;
    const current = user.get('membership') || 'active';
    if (current !== action.previous || member.get('membership') !== current) {
      throw new Error(`Membership changed for banned user ${action.uid}.`);
    }
    transaction.update(banRef, { previousMembership: action.previous });
    transaction.update(userRef, { membership: 'pending' });
    transaction.update(memberRef, { membership: 'pending' });
  });
}

async function applyPrepare(db, bucket, plan) {
  for (const action of plan.avatarActions) {
    if (action.copy) await copyLegacy(bucket, action);
    if (action.revokeDestination) {
      await revokeToken(bucket, action.destination);
    }
    if (action.revokeSource) await revokeToken(bucket, action.source);
  }
}

async function applyAccess(db, plan) {
  for (const action of plan.banActions) await synchronizeBan(db, action);
}

async function switchProfile(db, action) {
  await db.runTransaction(async (transaction) => {
    const userRef = db.collection('users').doc(action.uid);
    const memberRef = db.collection('memberDirectory').doc(action.uid);
    const [user, member] = await Promise.all([
      transaction.get(userRef),
      transaction.get(memberRef),
    ]);
    if (!user.exists) throw new Error(`users/${action.uid} disappeared.`);
    const data = user.data();
    const reference = classifyReference(data.profileImage);
    if (!reference || reference.uid !== action.uid) {
      throw new Error(`users/${action.uid}.profileImage changed unexpectedly.`);
    }
    const mismatch = projectionConflict(data, member.exists ? member.data() : null);
    if (mismatch) throw new Error(`users/${action.uid}: ${mismatch}.`);
    const currentRevision = Object.hasOwn(data, 'profileImageRevision')
      ? data.profileImageRevision
      : null;
    if (currentRevision !== action.currentRevision) {
      throw new Error(`users/${action.uid}.profileImageRevision changed unexpectedly.`);
    }
    if (reference.kind === 'canonical' && !action.switchRevision) return;

    const values = { profileImageRevision: action.targetRevision };
    if (reference.kind === 'legacy') {
      values.profileImage = canonicalPath(action.uid);
    }
    transaction.update(userRef, values);
    if (member.exists) {
      transaction.update(memberRef, values);
    }
  });
}

async function switchResponses(db, action) {
  const updates = [...action.responseUpdates.values()];
  for (let offset = 0; offset < updates.length; offset += BATCH_LIMIT) {
    const batch = db.batch();
    for (const update of updates.slice(offset, offset + BATCH_LIMIT)) {
      batch.update(update.ref, update.values, {
        lastUpdateTime: update.updateTime,
      });
    }
    await batch.commit();
  }
}

async function assertCurrentResponses(db, uid, expectedRevision) {
  const snapshot = await db
    .collectionGroup('participants')
    .where('userId', '==', uid)
    .get();
  for (const document of snapshot.docs) {
    const data = document.data();
    for (const field of RESPONSE_FIELDS) {
      const reference = classifyReference(data[field]);
      if (reference?.kind === 'legacy' && reference.uid === uid) {
        throw new Error(`Legacy response reference remains at ${document.ref.path}.`);
      }
      if (
        reference?.uid === uid &&
        data.profileImageRevision !== expectedRevision
      ) {
        throw new Error(`Avatar revision is stale at ${document.ref.path}.`);
      }
    }
  }
}

async function applySwitch(db, bucket, plan) {
  for (const action of plan.avatarActions) {
    await switchProfile(db, action);
    await switchResponses(db, action);
    await assertCurrentResponses(db, action.uid, action.targetRevision);

    const [user, member] = await Promise.all([
      db.collection('users').doc(action.uid).get(),
      db.collection('memberDirectory').doc(action.uid).get(),
    ]);
    if (user.get('profileImage') !== canonicalPath(action.uid)) {
      throw new Error(`users/${action.uid} did not switch to the canonical path.`);
    }
    if (member.exists && member.get('profileImage') !== canonicalPath(action.uid)) {
      throw new Error(`memberDirectory/${action.uid} did not switch atomically.`);
    }
    if (user.get('profileImageRevision') !== action.targetRevision) {
      throw new Error(`users/${action.uid} has a stale avatar revision.`);
    }
    if (
      member.exists &&
      member.get('profileImageRevision') !== action.targetRevision
    ) {
      throw new Error(`memberDirectory/${action.uid} has a stale avatar revision.`);
    }

    const destination = bucket.file(canonicalPath(action.uid));
    const [destinationMetadata] = await destination.getMetadata();
    if (hasDownloadToken({ customMetadata: destinationMetadata.metadata || {} })) {
      throw new Error(`Canonical avatar ${action.uid} regained a download token.`);
    }

    if (action.deleteSource) {
      await bucket.file(legacyPath(action.uid)).delete({
        ifGenerationMatch: action.source.generation,
      });
    }
  }
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(usage());
    return;
  }

  const app = initializeApp(
    {
      credential: applicationDefault(),
      projectId: EXPECTED_PROJECT,
      storageBucket: EXPECTED_BUCKET,
    },
    'avatar-privacy-migration',
  );
  try {
    const db = getFirestore(app);
    const bucket = getStorage(app).bucket(EXPECTED_BUCKET);
    console.log(
      `Project=${EXPECTED_PROJECT} bucket=${EXPECTED_BUCKET} phase=${options.phase} mode=${options.apply ? 'APPLY' : 'DRY RUN'}`,
    );
    const state = await loadState(db, bucket);
    const plan = buildPlan(state, options.phase);
    printPlan(plan);
    if (plan.conflicts.length > 0) {
      throw new Error('Conflict validation failed; no writes were attempted.');
    }
    if (!options.apply) {
      console.log('Dry run complete; no writes were attempted.');
      return;
    }
    if (options.phase === 'access') {
      await applyAccess(db, plan);
    } else if (options.phase === 'prepare') {
      await applyPrepare(db, bucket, plan);
    } else {
      await applySwitch(db, bucket, plan);
    }
    console.log('Apply complete. Repeat the same dry run; the gate passes only with no pending actions or conflicts.');
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
  EXPECTED_BUCKET,
  EXPECTED_PROJECT,
  buildPlan,
  canonicalPath,
  classifyReference,
  objectPathFromUrl,
  parseArgs,
  parseObjectPath,
};
