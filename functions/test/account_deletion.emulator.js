const assert = require('node:assert/strict');
const { after, before, describe, it } = require('node:test');

const { deleteApp, initializeApp } = require('firebase-admin/app');
const adminAuth = require('firebase-admin/auth');
const { Timestamp, getFirestore } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');

const {
  deleteUserAccount,
  deletedAuthorId,
} = require('../lib/account_deletion');
const { purgeCompany } = require('../lib/purge');

const projectId = 'echomeet-test';
const bucketName = `${projectId}.appspot.com`;
const deletingUid = 'f06-delete-user';
const sharedCompanyId = 'f06-shared-company';
const surveyId = 'f06-authored-survey';
const appointmentId = 'f06-authored-appointment';

let app;
let auth;
let db;
let bucket;

function assertLocalEmulators() {
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
  assert.equal(
    process.env.GCLOUD_PROJECT ?? process.env.GOOGLE_CLOUD_PROJECT,
    projectId,
    'the deletion boundary suite is pinned to echomeet-test',
  );
}

async function exists(path) {
  return (await db.doc(path).get()).exists;
}

async function objectExists(path) {
  return (await bucket.file(path).exists())[0];
}

async function expectMissingAuthUser(uid) {
  await assert.rejects(
    auth.getUser(uid),
    (error) => error?.code === 'auth/user-not-found',
  );
}

async function createAuthUser(uid) {
  return auth.createUser({
    uid,
    email: `${uid}@example.test`,
    emailVerified: true,
  });
}

before(async () => {
  assertLocalEmulators();
  app = initializeApp({ projectId, storageBucket: bucketName });
  auth = adminAuth.getAuth(app);
  db = getFirestore(app);
  bucket = getStorage(app).bucket();
});

after(async () => {
  if (app) await deleteApp(app);
});

describe('trusted destructive deletion emulator boundary', { concurrency: 1 }, () => {
  it('deletes avatar descendants and Auth only after personal app cleanup', async (t) => {
    await createAuthUser(deletingUid);
    await db.doc(`companies/${sharedCompanyId}`).set({ name: 'Shared company' });
    await db.doc(`users/${deletingUid}`).set({
      companyId: sharedCompanyId,
      role: 'user',
      membership: 'active',
      fullName: 'Deleting user',
    });
    await db.doc(`memberDirectory/${deletingUid}`).set({
      companyId: sharedCompanyId,
      role: 'user',
      membership: 'active',
      fullName: 'Deleting user',
    });
    await db.doc(`users/${deletingUid}/notes/profile-note`).set({ text: 'private' });
    await db.doc(`notes/${deletingUid}`).set({ owner: deletingUid });
    await db.doc(`notes/${deletingUid}/userNotes/root-note`).set({ text: 'private' });
    await db.doc(`surveys/${surveyId}`).set({
      companyId: sharedCompanyId,
      createdBy: deletingUid,
    });
    await db.doc(`surveys/${surveyId}/participants/deleting-vote`).set({
      userId: deletingUid,
    });
    await db.doc(`appointments/${appointmentId}`).set({
      companyId: sharedCompanyId,
      createdBy: deletingUid,
      participantUserIds: [deletingUid, 'unrelated-user'],
    });
    await db.doc(`appointments/${appointmentId}/participants/deleting-vote`).set({
      userId: deletingUid,
    });
    await db.doc(`companies/${sharedCompanyId}/bans/${deletingUid}`).set({
      bannedBy: 'other-user',
    });
    await db.doc(`companies/${sharedCompanyId}/bans/other-user`).set({
      bannedBy: deletingUid,
    });
    const legacyAvatar = `profile_images/${deletingUid}.jpg`;
    const privateAvatar = `profile_images/${deletingUid}/avatar.jpg`;
    await Promise.all([
      bucket.file(legacyAvatar).save(Buffer.from('legacy-avatar')),
      bucket.file(privateAvatar).save(Buffer.from('private-avatar')),
    ]);

    let authDeleteCalls = 0;
    t.mock.method(adminAuth, 'getAuth', () => ({
      deleteUser: async (uid) => {
        assert.equal(uid, deletingUid);
        authDeleteCalls += 1;
        assert.equal(await exists(`users/${uid}`), false);
        assert.equal(await exists(`memberDirectory/${uid}`), false);
        assert.equal(await exists(`users/${uid}/notes/profile-note`), false);
        assert.equal(await exists(`notes/${uid}`), false);
        assert.equal(await exists(`notes/${uid}/userNotes/root-note`), false);
        assert.equal(await objectExists(legacyAvatar), false);
        assert.equal(await objectExists(privateAvatar), false);
        assert.equal((await db.doc(`surveys/${surveyId}`).get()).get('createdBy'), deletedAuthorId);
        const appointment = await db.doc(`appointments/${appointmentId}`).get();
        assert.equal(appointment.get('createdBy'), deletedAuthorId);
        assert.deepEqual(appointment.get('participantUserIds'), ['unrelated-user']);
        assert.equal(
          await exists(`appointments/${appointmentId}/participants/deleting-vote`),
          false,
        );
        assert.equal(await exists(`companies/${sharedCompanyId}/bans/${uid}`), false);
        assert.equal(
          (await db.doc(`companies/${sharedCompanyId}/bans/other-user`).get()).get('bannedBy'),
          deletedAuthorId,
        );
        return auth.deleteUser(uid);
      },
    }));

    await deleteUserAccount(deletingUid);
    assert.equal(authDeleteCalls, 1);
    await expectMissingAuthUser(deletingUid);

    await deleteUserAccount(deletingUid);
    assert.equal(authDeleteCalls, 2);
  });

  it('purges a company twice while preserving and releasing member Auth users', async () => {
    const companyId = 'f06-purged-company';
    const memberIds = ['f06-member-one', 'f06-member-two'];
    await Promise.all(memberIds.map(createAuthUser));
    await db.doc(`companies/${companyId}`).set({
      name: 'Purged company',
      createdBy: 'different-owner',
      deletionScheduledFor: Timestamp.now(),
    });
    await db.doc(`companyDirectory/${companyId}`).set({ name: 'Purged company' });
    await db.doc('companyNames/f06-purged-name').set({ companyId });
    for (const uid of memberIds) {
      await db.doc(`users/${uid}`).set({
        companyId,
        role: uid.endsWith('one') ? 'admin' : 'moderator',
        membership: 'active',
        fullName: uid,
      });
      await db.doc(`memberDirectory/${uid}`).set({
        companyId,
        role: uid.endsWith('one') ? 'admin' : 'moderator',
        membership: 'active',
        fullName: uid,
      });
    }
    await db.doc('surveys/f06-company-survey').set({ companyId });
    await db.doc('surveys/f06-company-survey/participants/vote').set({
      userId: memberIds[0],
    });
    await db.doc('surveyAnswerKeys/f06-company-survey').set({ companyId });
    await db.doc('appointments/f06-company-appointment').set({ companyId });
    await db.doc('appointments/f06-company-appointment/participants/vote').set({
      userId: memberIds[1],
    });
    await db.doc(`companies/${companyId}/bans/banned-user`).set({
      bannedBy: memberIds[0],
    });

    await purgeCompany(companyId);
    await purgeCompany(companyId);

    for (const uid of memberIds) {
      const authUser = await auth.getUser(uid);
      const profile = await db.doc(`users/${uid}`).get();
      assert.equal(authUser.uid, uid);
      assert.equal(profile.get('companyId'), '');
      assert.equal(profile.get('role'), 'user');
      assert.equal(profile.get('membership'), 'active');
      assert.equal(await exists(`memberDirectory/${uid}`), false);
    }
    for (const path of [
      `companies/${companyId}`,
      `companies/${companyId}/bans/banned-user`,
      `companyDirectory/${companyId}`,
      'companyNames/f06-purged-name',
      'surveys/f06-company-survey',
      'surveys/f06-company-survey/participants/vote',
      'surveyAnswerKeys/f06-company-survey',
      'appointments/f06-company-appointment',
      'appointments/f06-company-appointment/participants/vote',
    ]) {
      assert.equal(await exists(path), false, path);
    }
  });
});
