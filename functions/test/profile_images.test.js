const assert = require('node:assert/strict');
const { after, describe, it, mock } = require('node:test');
const sharp = require('sharp');

const authAdmin = require('firebase-admin/auth');
const firestoreAdmin = require('firebase-admin/firestore');
const storageAdmin = require('firebase-admin/storage');

let activeEnvironment;
mock.method(authAdmin, 'getAuth', () => activeEnvironment.auth);
mock.method(firestoreAdmin, 'getFirestore', () => activeEnvironment.firestore);
mock.method(storageAdmin, 'getStorage', () => activeEnvironment.storage);
after(() => mock.restoreAll());

const {
  InvalidProfileImageError,
  ProfileImageAuthorizationError,
  ProfileImageRevisionError,
  ProfileImageStateError,
  deleteUploadedGenerationIfCurrent,
  nextProfileImageRevision,
  parseProfileImageUploadPayload,
  profileImagePathFor,
  sanitizeProfileImagePayload,
  uploadOwnProfileImage,
} = require('../lib/profile_images');

const uid = 'member-1';
const companyId = 'company-1';

function copy(value) {
  if (Array.isArray(value)) return value.map(copy);
  if (
    value != null &&
    typeof value === 'object' &&
    Object.getPrototypeOf(value) === Object.prototype
  ) {
    return Object.fromEntries(
      Object.entries(value).map(([key, entry]) => [key, copy(entry)]),
    );
  }
  return value;
}

class FakeReference {
  constructor(path) {
    this.path = path;
  }

  collection(name) {
    return new FakeCollection(`${this.path}/${name}`);
  }
}

class FakeCollection {
  constructor(path) {
    this.path = path;
  }

  doc(id) {
    return new FakeReference(`${this.path}/${id}`);
  }
}

class FakeFirestore {
  constructor(documents) {
    this.documents = new Map(
      Object.entries(documents).map(([path, value]) => [path, copy(value)]),
    );
    this.transactionCount = 0;
    this.beforeTransaction = undefined;
  }

  collection(name) {
    return new FakeCollection(name);
  }

  snapshots(references) {
    return references.map((reference) => {
      const value = this.documents.get(reference.path);
      return {
        exists: value != null,
        data: () => (value == null ? undefined : copy(value)),
      };
    });
  }

  async getAll(...references) {
    return this.snapshots(references);
  }

  async runTransaction(operation) {
    this.transactionCount += 1;
    if (this.beforeTransaction) {
      await this.beforeTransaction(this.transactionCount, this);
    }
    const updates = [];
    const transaction = {
      getAll: async (...references) => this.snapshots(references),
      update: (reference, fields) => updates.push([reference.path, fields]),
    };
    const result = await operation(transaction);
    for (const [path, fields] of updates) {
      const current = this.documents.get(path);
      if (current == null) throw new Error(`missing update target ${path}`);
      const next = { ...current };
      for (const [key, value] of Object.entries(fields)) {
        if (value?.constructor?.name === 'DeleteTransform') delete next[key];
        else next[key] = copy(value);
      }
      this.documents.set(path, next);
    }
    return result;
  }
}

function storageError(code) {
  return Object.assign(new Error(`storage-${code}`), { code });
}

class FakeStorage {
  constructor() {
    this.current = undefined;
    this.versions = new Map();
    this.nextGeneration = 1;
    this.saveCount = 0;
    this.deleteCount = 0;
    this.failMetadataUpdate = false;
  }

  bucket() {
    return {
      file: (_path, options = {}) => this.file(options.generation),
    };
  }

  file(generation) {
    const target = () =>
      generation == null
        ? this.current
        : this.versions.get(String(generation));
    return {
      getMetadata: async () => {
        const object = target();
        if (!object) throw storageError(404);
        return [copy(object.metadata)];
      },
      download: async () => {
        const object = target();
        if (!object) throw storageError(404);
        return [Buffer.from(object.bytes)];
      },
      save: async (bytes, options) => {
        const expected = String(options.preconditionOpts.ifGenerationMatch);
        const actual = this.current?.metadata.generation ?? '0';
        if (expected !== actual) throw storageError(412);
        const nextGeneration = String(this.nextGeneration++);
        const object = {
          bytes: Buffer.from(bytes),
          metadata: {
            generation: nextGeneration,
            size: bytes.length,
            contentType: options.metadata.contentType,
            cacheControl: options.metadata.cacheControl,
            metadata: copy(options.metadata.metadata ?? {}),
          },
        };
        this.current = object;
        this.versions.set(nextGeneration, object);
        this.saveCount += 1;
      },
      setMetadata: async (fields, options) => {
        if (this.failMetadataUpdate) throw new Error('metadata-update-failed');
        if (
          !this.current ||
          String(options.ifGenerationMatch) !== this.current.metadata.generation
        ) {
          throw storageError(412);
        }
        const metadata = { ...(this.current.metadata.metadata ?? {}) };
        for (const [key, value] of Object.entries(fields.metadata ?? {})) {
          if (value == null) delete metadata[key];
          else metadata[key] = value;
        }
        this.current.metadata.metadata = metadata;
      },
      delete: async (options) => {
        if (
          this.current &&
          String(options.ifGenerationMatch) !== this.current.metadata.generation
        ) {
          throw storageError(412);
        }
        this.current = undefined;
        this.deleteCount += 1;
      },
    };
  }
}

function environment(overrides = {}) {
  const profile = {
    fullName: 'Member One',
    companyId,
    role: 'user',
    membership: 'active',
    profileImageRevision: 0,
    ...overrides.profile,
  };
  const member = {
    fullName: profile.fullName,
    companyId: profile.companyId,
    role: profile.role,
    membership: profile.membership,
    profileImageRevision: profile.profileImageRevision,
    ...overrides.member,
  };
  const documents = {};
  if (overrides.profile !== null) documents[`users/${uid}`] = profile;
  if (overrides.member !== null) documents[`memberDirectory/${uid}`] = member;
  if (overrides.company !== null) {
    documents[`companies/${companyId}`] = {
      name: 'Company One',
      ...overrides.company,
    };
  }
  if (overrides.banned) {
    documents[`companies/${companyId}/bans/${uid}`] = { bannedBy: 'admin-1' };
  }
  if (overrides.deleting) {
    documents[`accountDeletionLocks/${uid}`] = { startedAt: 'now' };
  }
  const firestore = new FakeFirestore(documents);
  const storage = new FakeStorage();
  const auth = {
    getUser: async () => {
      if (overrides.authDeleted) throw { code: 'auth/user-not-found' };
      return {
        disabled: false,
        emailVerified: true,
        ...overrides.auth,
      };
    },
  };
  activeEnvironment = { auth, firestore, storage };
  return activeEnvironment;
}

async function encodedImage(format, options = {}) {
  const pipeline = sharp({
    create: {
      width: options.width ?? 48,
      height: options.height ?? 32,
      channels: 3,
      background: options.background ?? '#8a5cf5',
    },
  });
  if (options.exif) pipeline.withExif({ IFD0: { Artist: 'hidden author' } });
  return format === 'png' ? pipeline.png().toBuffer() : pipeline.jpeg().toBuffer();
}

function upload(bytes, overrides = {}) {
  return {
    imageBase64: bytes.toString('base64'),
    format: 'jpeg',
    expectedRevision: 0,
    ...overrides,
  };
}

describe('trusted profile image parser and sanitizer', () => {
  it('requires exactly one image field and an optimistic revision', () => {
    assert.deepEqual(
      parseProfileImageUploadPayload({
        jpegBase64: 'abc',
        expectedRevision: 6,
      }),
      { imageBase64: 'abc', format: 'jpeg', expectedRevision: 6 },
    );
    assert.deepEqual(
      parseProfileImageUploadPayload({
        pngBase64: 'def',
        expectedRevision: 7,
      }),
      {
        imageBase64: 'def',
        format: 'png',
        expectedRevision: 7,
      },
    );
    for (const payload of [
      {},
      { jpegBase64: 'x' },
      { pngBase64: 'x' },
      { jpegBase64: 'x', pngBase64: 'y' },
      { jpegBase64: 'x', expectedRevision: -1 },
      { jpegBase64: 'x', expectedRevision: 0, requestId: 'not-accepted' },
      { jpegBase64: 'x', expectedRevision: 0, extra: true },
    ]) {
      assert.throws(
        () => parseProfileImageUploadPayload(payload),
        InvalidProfileImageError,
      );
    }
  });

  it('re-encodes valid JPEG and PNG as metadata-free JPEG', async () => {
    const jpeg = await encodedImage('jpeg', { exif: true });
    assert.ok((await sharp(jpeg).metadata()).exif);
    const png = await encodedImage('png');

    for (const [input, format] of [
      [jpeg, 'jpeg'],
      [png, 'png'],
    ]) {
      const output = await sanitizeProfileImagePayload(
        input.toString('base64'),
        format,
      );
      const metadata = await sharp(output).metadata();
      assert.equal(metadata.format, 'jpeg');
      assert.equal(metadata.width, 48);
      assert.equal(metadata.height, 32);
      assert.equal(metadata.exif, undefined);
      assert.equal(metadata.icc, undefined);
      assert.equal(metadata.xmp, undefined);
    }
  });

  it('rejects malformed, format-mismatched, oversized and polyglot payloads', async () => {
    const jpeg = await encodedImage('jpeg');
    const png = await encodedImage('png');
    const oversized = await encodedImage('jpeg', { width: 1025, height: 1 });
    const jpegControl = Buffer.concat([
      jpeg.subarray(0, -2),
      Buffer.from('\n<script>alert(1)</script>\n'),
      jpeg.subarray(-2),
    ]);
    const pngControl = Buffer.concat([png, Buffer.from('<script>x</script>')]);
    const overFiveMiB = Buffer.alloc(5 * 1024 * 1024 + 1);

    for (const [payload, format] of [
      ['not base64', 'jpeg'],
      ['YWJjZA==\n', 'jpeg'],
      [png.toString('base64'), 'jpeg'],
      [jpeg.toString('base64'), 'png'],
      [oversized.toString('base64'), 'jpeg'],
      [jpegControl.toString('base64'), 'jpeg'],
      [pngControl.toString('base64'), 'png'],
      [overFiveMiB.toString('base64'), 'jpeg'],
    ]) {
      await assert.rejects(
        sanitizeProfileImagePayload(payload, format),
        InvalidProfileImageError,
      );
    }
  });

  it('derives the trusted path/revision and generation-safe cleanup', async () => {
    assert.equal(
      profileImagePathFor('owner-123'),
      'profile_images/owner-123/avatar.jpg',
    );
    assert.equal(nextProfileImageRevision(undefined), 1);
    assert.equal(nextProfileImageRevision(7), 8);
    assert.throws(() => nextProfileImageRevision(-1), ProfileImageStateError);

    let receivedOptions;
    await deleteUploadedGenerationIfCurrent(
      {
        delete: async (options) => {
          receivedOptions = options;
          throw { code: 412 };
        },
      },
      'generation-a',
    );
    assert.deepEqual(receivedOptions, {
      ignoreNotFound: true,
      ifGenerationMatch: 'generation-a',
    });
  });
});

describe('trusted profile image upload boundary', { concurrency: false }, () => {
  it('stores canonical JPEG, advances both projections, and creates no token', async () => {
    const env = environment();
    const input = await encodedImage('png');
    const result = await uploadOwnProfileImage(
      uid,
      upload(input, { format: 'png' }),
    );

    assert.deepEqual(result, {
      path: `profile_images/${uid}/avatar.jpg`,
      revision: 1,
    });
    const storedMetadata = await sharp(env.storage.current.bytes).metadata();
    assert.equal(storedMetadata.format, 'jpeg');
    assert.deepEqual(env.storage.current.metadata.metadata, {});
    assert.equal(env.firestore.documents.get(`users/${uid}`).profileImageRevision, 1);
    assert.equal(
      env.firestore.documents.get(`memberDirectory/${uid}`).profileImageRevision,
      1,
    );
  });

  it('rejects a duplicate before touching Storage again', async () => {
    const env = environment();
    const input = await encodedImage('jpeg');
    const request = upload(input);
    await uploadOwnProfileImage(uid, request);
    const saveCount = env.storage.saveCount;
    await assert.rejects(
      uploadOwnProfileImage(uid, request),
      ProfileImageRevisionError,
    );
    assert.equal(env.storage.saveCount, saveCount);
  });

  it('rejects an explicit stale revision before touching Storage', async () => {
    const env = environment({
      profile: { profileImageRevision: 4 },
      member: { profileImageRevision: 4 },
    });
    const input = await encodedImage('jpeg');
    await assert.rejects(
      uploadOwnProfileImage(uid, upload(input, { expectedRevision: 3 })),
      ProfileImageRevisionError,
    );
    assert.equal(env.storage.saveCount, 0);
  });

  it('removes the uploaded object when metadata hardening fails', async () => {
    const env = environment();
    env.storage.failMetadataUpdate = true;
    const input = await encodedImage('jpeg');
    await assert.rejects(
      uploadOwnProfileImage(uid, upload(input)),
      /metadata-update-failed/,
    );
    assert.equal(env.storage.current, undefined);
    assert.equal(env.storage.deleteCount, 1);
    assert.equal(env.firestore.documents.get(`users/${uid}`).profileImageRevision, 0);
  });

  it('rechecks projection revision in the final transaction and rolls back', async () => {
    const env = environment();
    env.firestore.beforeTransaction = (count, store) => {
      if (count === 2) {
        store.documents.get(`memberDirectory/${uid}`).profileImageRevision = 9;
      }
    };
    const input = await encodedImage('jpeg');
    await assert.rejects(
      uploadOwnProfileImage(uid, upload(input)),
      ProfileImageStateError,
    );
    assert.equal(env.storage.current, undefined);
  });

  it('fails closed for missing/deleted/disabled/banned/inactive/cross-company/closing state', async () => {
    const input = await encodedImage('jpeg');
    const cases = [
      [{ member: null }, ProfileImageStateError, 'missing member'],
      [{ profile: null }, ProfileImageStateError, 'deleted profile'],
      [{ authDeleted: true }, ProfileImageStateError, 'deleted Auth'],
      [{ auth: { disabled: true } }, ProfileImageStateError, 'disabled Auth'],
      [{ deleting: true }, ProfileImageStateError, 'deletion lock'],
      [{ banned: true }, ProfileImageAuthorizationError, 'ban'],
      [
        { profile: { membership: 'pending' }, member: { membership: 'pending' } },
        ProfileImageAuthorizationError,
        'inactive membership',
      ],
      [
        { member: { companyId: 'company-2' } },
        ProfileImageStateError,
        'cross-company projection',
      ],
      [{ company: null }, ProfileImageStateError, 'missing company'],
      [
        { company: { deletionScheduledFor: null } },
        ProfileImageStateError,
        'present-null closing marker',
      ],
    ];

    for (const [overrides, ErrorType, label] of cases) {
      const env = environment(overrides);
      await assert.rejects(
        uploadOwnProfileImage(uid, upload(input)),
        (error) => {
          assert.ok(error instanceof ErrorType, `${label}: ${error}`);
          return true;
        },
      );
      assert.equal(env.storage.saveCount, 0, label);
    }
  });
});
