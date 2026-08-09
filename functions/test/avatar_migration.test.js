'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  EXPECTED_BUCKET,
  buildPlan,
  canonicalPath,
  classifyReference,
  parseArgs,
} = require('../scripts/migrate_avatar_privacy');

test('avatar migration accepts only the exact project and defaults to dry run', () => {
  assert.deepEqual(
    parseArgs(['--project', 'echomeet-app', '--phase', 'prepare']),
    {
      apply: false,
      help: false,
      phase: 'prepare',
      project: 'echomeet-app',
    },
  );
  assert.throws(
    () => parseArgs(['--project', 'another-project', '--phase', 'prepare']),
    /must be exactly/,
  );
});

test('avatar references accept canonical paths and legacy Firebase URLs only', () => {
  assert.equal(canonicalPath('alice'), 'profile_images/alice/avatar.jpg');
  assert.deepEqual(classifyReference(canonicalPath('alice')), {
    kind: 'canonical',
    path: 'profile_images/alice/avatar.jpg',
    uid: 'alice',
  });
  assert.deepEqual(
    classifyReference(
      `https://firebasestorage.googleapis.com/v0/b/${EXPECTED_BUCKET}/o/profile_images%2Falice.jpg?alt=media&token=secret`,
    ),
    { kind: 'legacy', path: 'profile_images/alice.jpg', uid: 'alice' },
  );
  assert.equal(classifyReference('https://example.test/avatar.jpg'), null);
  assert.equal(
    classifyReference(
      'https://firebasestorage.googleapis.com/v0/b/other/o/profile_images%2Falice.jpg',
    ),
    null,
  );
});

test('switch initializes one shared revision in profiles and response snapshots', () => {
  const userData = {
    fullName: 'Alice',
    companyId: 'acme',
    role: 'user',
    membership: 'active',
    profileImage: 'profile_images/alice.jpg',
  };
  const memberData = {
    fullName: 'Alice',
    companyId: 'acme',
    role: 'user',
    membership: 'active',
    profileImage: 'profile_images/alice.jpg',
  };
  const user = { data: () => userData };
  const member = { data: () => memberData };
  const response = {
    data: () => ({
      userId: 'alice',
      imageProfile: 'profile_images/alice.jpg',
    }),
    ref: { path: 'surveys/s1/participants/alice' },
    updateTime: 'version-1',
  };
  const source = {
    kind: 'legacy',
    path: 'profile_images/alice.jpg',
    uid: 'alice',
    crc32c: 'same',
    customMetadata: {},
    generation: '1',
  };
  const destination = {
    kind: 'canonical',
    path: canonicalPath('alice'),
    uid: 'alice',
    crc32c: 'same',
    customMetadata: {},
    generation: '2',
  };

  const plan = buildPlan(
    {
      users: new Map([['alice', user]]),
      members: new Map([['alice', member]]),
      responses: [response],
      bans: [],
      objects: new Map([
        [source.path, source],
        [destination.path, destination],
      ]),
    },
    'switch',
  );

  assert.deepEqual(plan.conflicts, []);
  assert.equal(plan.avatarActions[0].targetRevision, 1);
  assert.equal(plan.avatarActions[0].switchRevision, true);
  assert.deepEqual(
    plan.avatarActions[0].responseUpdates.get(response.ref.path).values,
    {
      imageProfile: canonicalPath('alice'),
      profileImageRevision: 1,
    },
  );
});
