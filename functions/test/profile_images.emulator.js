const assert = require('node:assert/strict');
const { after, before, describe, it } = require('node:test');

const { deleteApp, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { Timestamp, getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const sharp = require('sharp');

const {
  ProfileImageAuthorizationError,
  ProfileImageRevisionError,
  ProfileImageStateError,
  parseProfileImageUploadPayload,
  profileImagePathFor,
  uploadOwnProfileImage,
} = require('../lib/profile_images');

const projectId = 'echomeet-test';
const bucketName = `${projectId}.appspot.com`;
const userIds = [
  'f03-valid-jpeg',
  'f03-valid-png',
  'f03-stale',
  'f03-no-member',
  'f03-disabled',
  'f03-deleted',
  'f03-banned',
  'f03-inactive',
  'f03-cross-company',
  'f03-closing',
];

let app;
let auth;
let db;
let bucket;
let jpegBase64;
let pngBase64;

function assertedEmulatorEnvironment() {
  for (const name of [
    'FIREBASE_AUTH_EMULATOR_HOST',
    'FIRESTORE_EMULATOR_HOST',
    'FIREBASE_STORAGE_EMULATOR_HOST',
  ]) {
    assert.match(
      process.env[name] ?? '',
      /^(127[.]0[.]0[.]1|localhost):\d+$/,
      `${name} must target a local emulator`,
    );
  }

  let configuredProject;
  try {
    configuredProject = JSON.parse(process.env.FIREBASE_CONFIG ?? '{}').projectId;
  } catch (_) {
    configuredProject = undefined;
  }
  assert.equal(
    process.env.GCLOUD_PROJECT ??
      process.env.GOOGLE_CLOUD_PROJECT ??
      configuredProject,
    projectId,
    'the profile-image boundary suite is pinned to echomeet-test',
  );
}

async function ignoreMissingAuthUser(uid) {
  try {
    await auth.deleteUser(uid);
  } catch (error) {
    if (error?.code !== 'auth/user-not-found') throw error;
  }
}

async function clearFixture(uid) {
  const companyId = `company-${uid}`;
  await ignoreMissingAuthUser(uid);
  await Promise.all([
    db.doc(`accountDeletionLocks/${uid}`).delete(),
    db.doc(`memberDirectory/${uid}`).delete(),
    db.doc(`users/${uid}`).delete(),
    db.doc(`companies/${companyId}/bans/${uid}`).delete(),
  ]);
  await db.doc(`companies/${companyId}`).delete();
  await bucket.deleteFiles({ prefix: `profile_images/${uid}/` });
}

async function seedUser(
  uid,
  {
    authRecord = true,
    disabled = false,
    profileCompanyId = `company-${uid}`,
    memberCompanyId = profileCompanyId,
    membership = 'active',
    member = true,
    company = {},
    banned = false,
  } = {},
) {
  const email = `${uid}@example.test`;
  if (authRecord) {
    await auth.createUser({
      uid,
      email,
      emailVerified: true,
      disabled,
    });
  }

  await db.doc(`users/${uid}`).set({
    membership,
    fullName: uid,
    birthdate: '',
    email,
    role: 'user',
    createdAt: Timestamp.now(),
    companyId: profileCompanyId,
  });
  if (member) {
    await db.doc(`memberDirectory/${uid}`).set({
      membership,
      fullName: uid,
      role: 'user',
      companyId: memberCompanyId,
    });
  }
  await db.doc(`companies/${profileCompanyId}`).set({
    name: profileCompanyId,
    ...company,
  });
  if (banned) {
    await db.doc(`companies/${profileCompanyId}/bans/${uid}`).set({
      name: uid,
      bannedAt: Timestamp.now(),
      bannedBy: 'f03-admin',
      previousMembership: 'active',
    });
  }
}

function versionedUpload(imageKey, imageBase64, expectedRevision) {
  return parseProfileImageUploadPayload({
    [imageKey]: imageBase64,
    expectedRevision,
  });
}

before(async () => {
  assertedEmulatorEnvironment();
  app = initializeApp({ projectId, storageBucket: bucketName });
  auth = getAuth(app);
  db = getFirestore(app);
  bucket = getStorage(app).bucket();

  for (const uid of userIds) await clearFixture(uid);

  const jpeg = await sharp({
    create: {
      width: 64,
      height: 32,
      channels: 3,
      background: '#805ad5',
    },
  })
    .withExif({ IFD0: { Artist: 'private audit metadata' } })
    .jpeg({ quality: 90 })
    .toBuffer();
  assert.ok((await sharp(jpeg).metadata()).exif);
  jpegBase64 = jpeg.toString('base64');

  pngBase64 = (
    await sharp({
      create: {
        width: 32,
        height: 64,
        channels: 4,
        background: '#2b6cb0',
      },
    })
      .png()
      .toBuffer()
  ).toString('base64');
});

after(async () => {
  if (db && auth && bucket) {
    for (const uid of userIds) await clearFixture(uid);
  }
  if (app) await deleteApp(app);
});

describe('trusted profile-image emulator boundary', { concurrency: 1 }, () => {
  it('stores a metadata-free JPEG and rejects a sequential duplicate as stale', async () => {
    const uid = 'f03-valid-jpeg';
    await seedUser(uid);
    const upload = versionedUpload(
      'jpegBase64',
      jpegBase64,
      0,
    );

    const first = await uploadOwnProfileImage(uid, upload);
    assert.deepEqual(first, { path: profileImagePathFor(uid), revision: 1 });

    const file = bucket.file(first.path);
    const [firstObjectMetadata] = await file.getMetadata();
    const [storedBytes] = await file.download();
    const storedImageMetadata = await sharp(storedBytes).metadata();
    assert.equal(firstObjectMetadata.contentType, 'image/jpeg');
    assert.equal(
      firstObjectMetadata.metadata?.firebaseStorageDownloadTokens,
      undefined,
    );
    assert.equal(storedImageMetadata.format, 'jpeg');
    assert.equal(storedImageMetadata.width, 64);
    assert.equal(storedImageMetadata.height, 32);
    assert.equal(storedImageMetadata.exif, undefined);
    assert.equal(storedImageMetadata.icc, undefined);
    assert.equal(storedImageMetadata.xmp, undefined);

    await assert.rejects(
      uploadOwnProfileImage(uid, upload),
      ProfileImageRevisionError,
    );
    const [duplicateObjectMetadata] = await file.getMetadata();
    assert.equal(duplicateObjectMetadata.generation, firstObjectMetadata.generation);

    const [profile, member] = await Promise.all([
      db.doc(`users/${uid}`).get(),
      db.doc(`memberDirectory/${uid}`).get(),
    ]);
    assert.equal(profile.get('profileImage'), first.path);
    assert.equal(profile.get('profileImageRevision'), 1);
    assert.equal(member.get('profileImage'), first.path);
    assert.equal(member.get('profileImageRevision'), 1);
  });

  it('accepts a declared PNG but stores the same trusted JPEG format', async () => {
    const uid = 'f03-valid-png';
    await seedUser(uid);
    const upload = versionedUpload(
      'pngBase64',
      pngBase64,
      0,
    );

    const result = await uploadOwnProfileImage(uid, upload);
    const [storedBytes] = await bucket.file(result.path).download();
    const metadata = await sharp(storedBytes).metadata();
    assert.deepEqual(result, { path: profileImagePathFor(uid), revision: 1 });
    assert.equal(metadata.format, 'jpeg');
    assert.equal(metadata.width, 32);
    assert.equal(metadata.height, 64);
  });

  it('rejects a stale revision before creating a Storage object', async () => {
    const uid = 'f03-stale';
    await seedUser(uid);
    const upload = versionedUpload(
      'jpegBase64',
      jpegBase64,
      1,
    );

    await assert.rejects(
      uploadOwnProfileImage(uid, upload),
      ProfileImageRevisionError,
    );
    assert.equal((await bucket.file(profileImagePathFor(uid)).exists())[0], false);
  });

  it('rejects missing, disabled and deleted identities without writing Storage', async () => {
    const cases = [
      ['f03-no-member', { member: false }],
      ['f03-disabled', { disabled: true }],
      ['f03-deleted', { authRecord: false }],
    ];
    for (const [uid, options] of cases) {
      await seedUser(uid, options);
      const upload = versionedUpload(
        'jpegBase64',
        jpegBase64,
        0,
      );
      await assert.rejects(uploadOwnProfileImage(uid, upload), ProfileImageStateError);
      assert.equal(
        (await bucket.file(profileImagePathFor(uid)).exists())[0],
        false,
        uid,
      );
    }
  });

  it('rejects banned, cross-company and closing membership state', async () => {
    const bannedUid = 'f03-banned';
    await seedUser(bannedUid, { banned: true });
    await assert.rejects(
      uploadOwnProfileImage(
        bannedUid,
        versionedUpload(
          'jpegBase64',
          jpegBase64,
          0,
        ),
      ),
      ProfileImageAuthorizationError,
    );

    const inactiveUid = 'f03-inactive';
    await seedUser(inactiveUid, { membership: 'pending' });
    await assert.rejects(
      uploadOwnProfileImage(
        inactiveUid,
        versionedUpload(
          'jpegBase64',
          jpegBase64,
          0,
        ),
      ),
      ProfileImageAuthorizationError,
    );

    const crossCompanyUid = 'f03-cross-company';
    await seedUser(crossCompanyUid, {
      memberCompanyId: 'company-f03-rival',
    });
    await assert.rejects(
      uploadOwnProfileImage(
        crossCompanyUid,
        versionedUpload(
          'jpegBase64',
          jpegBase64,
          0,
        ),
      ),
      ProfileImageStateError,
    );

    const closingUid = 'f03-closing';
    await seedUser(closingUid, { company: { deletionScheduledFor: null } });
    await assert.rejects(
      uploadOwnProfileImage(
        closingUid,
        versionedUpload(
          'jpegBase64',
          jpegBase64,
          0,
        ),
      ),
      ProfileImageStateError,
    );

    for (const uid of [
      bannedUid,
      inactiveUid,
      crossCompanyUid,
      closingUid,
    ]) {
      assert.equal(
        (await bucket.file(profileImagePathFor(uid)).exists())[0],
        false,
        uid,
      );
    }
  });
});
