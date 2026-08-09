import { readFileSync } from 'node:fs';
import { after, before, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { deleteDoc, doc, setDoc, updateDoc } from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'echomeet-test',
    firestore: {
      host: '127.0.0.1',
      port: 8080,
    },
    storage: {
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 9199,
    },
  });

  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await Promise.all([
      setDoc(doc(db, 'memberDirectory', 'storage-alice'), {
        fullName: 'Alice', companyId: 'storage-acme', role: 'user',
        membership: 'active',
      }),
      setDoc(doc(db, 'memberDirectory', 'storage-bob'), {
        fullName: 'Bob', companyId: 'storage-acme', role: 'user',
        membership: 'active',
      }),
      setDoc(doc(db, 'memberDirectory', 'storage-carol'), {
        fullName: 'Carol', companyId: 'storage-rival', role: 'user',
        membership: 'active',
      }),
      setDoc(doc(db, 'memberDirectory', 'storage-pending'), {
        fullName: 'Pending', companyId: 'storage-acme', role: 'user',
        membership: 'pending',
      }),
      setDoc(doc(db, 'memberDirectory', 'storage-banned'), {
        fullName: 'Banned', companyId: 'storage-acme', role: 'user',
        membership: 'pending',
      }),
      setDoc(
        doc(db, 'companies', 'storage-acme', 'bans', 'storage-banned'),
        {
          name: 'Banned', bannedAt: new Date(), bannedBy: 'storage-alice',
          previousMembership: 'active',
        },
      ),
    ]);

    await uploadBytes(
      ref(ctx.storage(), 'profile_images/storage-alice.jpg'),
      new Uint8Array([1, 2, 3]),
      { contentType: 'image/jpeg' },
    );
    await Promise.all([
      uploadBytes(
        ref(ctx.storage(), 'profile_images/storage-alice/avatar.jpg'),
        new Uint8Array([4, 5, 6]),
        { contentType: 'image/jpeg' },
      ),
      uploadBytes(
        ref(ctx.storage(), 'profile_images/storage-bob/avatar.jpg'),
        new Uint8Array([7, 8, 9]),
        { contentType: 'image/jpeg' },
      ),
    ]);
  });
});

after(async () => {
  await testEnv?.cleanup();
});

const storageAs = (uid, verified = true) =>
  testEnv.authenticatedContext(uid, { email_verified: verified }).storage();

describe('profile image storage', () => {
  it('rejects every direct client create or replacement, including the owner', async () => {
    const canonical = 'profile_images/storage-alice/avatar.jpg';
    await assertFails(
      uploadBytes(
        ref(storageAs('storage-alice'), canonical),
        new Uint8Array([1, 2, 3]),
        { contentType: 'image/png' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(
          storageAs('storage-alice'),
          'profile_images/storage-alice/other.jpg',
        ),
        new Uint8Array([1, 2, 3]),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(storageAs('storage-alice'), canonical),
        new Uint8Array([1, 2, 3]),
        {
          contentType: 'image/jpeg',
          customMetadata: { firebaseStorageDownloadTokens: 'bearer-token' },
        },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(storageAs('storage-alice', false), canonical),
        new Uint8Array([1, 2, 3]),
        { contentType: 'image/jpeg' },
      ),
    );
    await assertFails(
      uploadBytes(
        ref(storageAs('storage-bob'), canonical),
        new Uint8Array([1, 2, 3]),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  it('allows the owner to read the canonical image', async () => {
    await assertSucceeds(
      getBytes(
        ref(
          storageAs('storage-alice'),
          'profile_images/storage-alice/avatar.jpg',
        ),
      ),
    );
  });

  it('lets active colleagues read but denies other-company and pending users', async () => {
    const path = 'profile_images/storage-alice/avatar.jpg';
    await assertSucceeds(getBytes(ref(storageAs('storage-bob'), path)));
    await assertFails(getBytes(ref(storageAs('storage-carol'), path)));
    await assertFails(getBytes(ref(storageAs('storage-pending'), path)));
  });

  it('supports authenticated reads of legacy objects but never recreates them', async () => {
    const legacyPath = 'profile_images/storage-alice.jpg';
    await assertSucceeds(
      getBytes(ref(storageAs('storage-alice'), legacyPath)),
    );
    await assertSucceeds(getBytes(ref(storageAs('storage-bob'), legacyPath)));
    await assertFails(
      uploadBytes(
        ref(storageAs('storage-alice'), legacyPath),
        new Uint8Array([4, 5, 6]),
        { contentType: 'image/jpeg' },
      ),
    );
  });

  it('denies a mirrored banned member and allows reads after unban restores membership', async () => {
    const path = 'profile_images/storage-alice/avatar.jpg';
    await assertFails(getBytes(ref(storageAs('storage-banned'), path)));

    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await updateDoc(
        doc(ctx.firestore(), 'memberDirectory', 'storage-banned'),
        { membership: 'active' },
      );
      await deleteDoc(
        doc(
          ctx.firestore(),
          'companies',
          'storage-acme',
          'bans',
          'storage-banned',
        ),
      );
    });

    await assertSucceeds(getBytes(ref(storageAs('storage-banned'), path)));
  });

  it('blocks client deletion once trusted account deletion starts', async () => {
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(
        doc(ctx.firestore(), 'accountDeletionLocks', 'storage-bob'),
        {
          startedAt: new Date(),
          expiresAt: new Date(Date.now() + 60 * 60 * 1000),
        },
      );
    });

    await assertFails(
      deleteObject(
        ref(
          storageAs('storage-bob'),
          'profile_images/storage-bob/avatar.jpg',
        ),
      ),
    );
  });

  it('allows an active verified owner to delete their canonical image', async () => {
    await assertSucceeds(
      deleteObject(
        ref(
          storageAs('storage-alice'),
          'profile_images/storage-alice/avatar.jpg',
        ),
      ),
    );
  });
});
