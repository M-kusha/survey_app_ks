import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Transaction } from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { randomUUID } from 'node:crypto';
import * as sharpModule from 'sharp';

// This functions package is compiled as CommonJS. Sharp 0.35 publishes a
// callable CommonJS export but describes it as a default export to TypeScript.
const sharp = sharpModule as unknown as typeof sharpModule.default;

const maximumInputBytes = 5 * 1024 * 1024;
const maximumRollbackBytes = 15 * 1024 * 1024;
const maximumDimension = 1024;
const maximumBase64Length = Math.ceil(maximumInputBytes / 3) * 4;
const maximumProfileImageRevision = 2_147_483_647;

export const profileImagePathFor = (uid: string): string =>
  `profile_images/${uid}/avatar.jpg`;

export class InvalidProfileImageError extends Error {
  constructor() {
    super('invalid-profile-image');
    this.name = 'InvalidProfileImageError';
  }
}

export class ProfileImageStateError extends Error {
  constructor(message = 'profile-unavailable') {
    super(message);
    this.name = 'ProfileImageStateError';
  }
}

export function nextProfileImageRevision(current: unknown): number {
  const value = current ?? 0;
  if (
    !Number.isInteger(value) ||
    (value as number) < 0 ||
    (value as number) >= maximumProfileImageRevision
  ) {
    throw new ProfileImageStateError();
  }
  return (value as number) + 1;
}

function invalidImage(): never {
  throw new InvalidProfileImageError();
}

/**
 * Strictly decodes the callable payload and re-encodes it as a bounded JPEG.
 *
 * Sharp strips EXIF, ICC, XMP and other metadata by default. The explicit
 * re-encode is the trusted boundary: client-side sanitizing remains useful for
 * bandwidth, but is not part of the security guarantee.
 */
export async function sanitizeProfileImagePayload(
  jpegBase64: unknown,
): Promise<Buffer> {
  if (
    typeof jpegBase64 !== 'string' ||
    jpegBase64.length === 0 ||
    jpegBase64.length > maximumBase64Length ||
    jpegBase64.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(jpegBase64)
  ) {
    return invalidImage();
  }

  const input = Buffer.from(jpegBase64, 'base64');
  if (
    input.length === 0 ||
    input.length >= maximumInputBytes ||
    input.toString('base64') !== jpegBase64 ||
    input.length < 4 ||
    input[0] !== 0xff ||
    input[1] !== 0xd8 ||
    input[2] !== 0xff ||
    input[input.length - 2] !== 0xff ||
    input[input.length - 1] !== 0xd9
  ) {
    return invalidImage();
  }

  try {
    const image = sharp(input, {
      failOn: 'warning',
      limitInputPixels: 40 * 1024 * 1024,
      sequentialRead: true,
    });
    const metadata = await image.metadata();
    if (
      metadata.format !== 'jpeg' ||
      metadata.width == null ||
      metadata.height == null ||
      metadata.width < 1 ||
      metadata.height < 1 ||
      (metadata.pages != null && metadata.pages !== 1)
    ) {
      return invalidImage();
    }

    const output = await image
      .rotate()
      .resize({
        width: maximumDimension,
        height: maximumDimension,
        fit: 'inside',
        withoutEnlargement: true,
      })
      .jpeg({
        quality: 85,
        chromaSubsampling: '4:2:0',
        progressive: false,
        optimiseCoding: true,
      })
      .toBuffer();

    if (
      output.length === 0 ||
      output.length >= maximumInputBytes ||
      output[0] !== 0xff ||
      output[1] !== 0xd8 ||
      output[output.length - 2] !== 0xff ||
      output[output.length - 1] !== 0xd9
    ) {
      return invalidImage();
    }
    return output;
  } catch (error) {
    if (error instanceof InvalidProfileImageError) throw error;
    return invalidImage();
  }
}

function hasOnlyProjectionFields(data: Record<string, unknown>): boolean {
  const allowed = new Set([
    'fullName',
    'companyId',
    'role',
    'membership',
    'profileImage',
    'profileImageRevision',
  ]);
  return Object.keys(data).every((key) => allowed.has(key));
}

function assertMatchingProjection(
  profile: Record<string, unknown>,
  member: Record<string, unknown> | undefined,
): void {
  const companyId =
    typeof profile.companyId === 'string' ? profile.companyId.trim() : '';
  if (companyId.length === 0) {
    if (member != null) throw new ProfileImageStateError();
    return;
  }

  const revision = profile.profileImageRevision;
  if (
    revision != null &&
    (!Number.isInteger(revision) ||
      (revision as number) < 0 ||
      (revision as number) > maximumProfileImageRevision)
  ) {
    throw new ProfileImageStateError();
  }

  if (
    member == null ||
    !hasOnlyProjectionFields(member) ||
    member.fullName !== profile.fullName ||
    member.companyId !== profile.companyId ||
    member.role !== profile.role ||
    member.membership !== (profile.membership ?? 'active') ||
    member.profileImageRevision !== revision
  ) {
    throw new ProfileImageStateError();
  }
}

async function assertProfileWritable(uid: string): Promise<void> {
  const db = getFirestore();
  const user = db.collection('users').doc(uid);
  const member = db.collection('memberDirectory').doc(uid);
  const lock = db.collection('accountDeletionLocks').doc(uid);
  const [lockSnapshot, userSnapshot, memberSnapshot] = await db.getAll(
    lock,
    user,
    member,
  );
  if (lockSnapshot.exists || !userSnapshot.exists) {
    throw new ProfileImageStateError();
  }
  assertMatchingProjection(
    userSnapshot.data() ?? {},
    memberSnapshot.exists ? memberSnapshot.data() : undefined,
  );
}

async function synchronizeProfileReference(
  uid: string,
  path: string,
): Promise<number> {
  const db = getFirestore();
  const user = db.collection('users').doc(uid);
  const member = db.collection('memberDirectory').doc(uid);
  const lock = db.collection('accountDeletionLocks').doc(uid);

  return db.runTransaction(async (transaction: Transaction) => {
    const [lockSnapshot, userSnapshot, memberSnapshot] =
      await transaction.getAll(lock, user, member);
    if (lockSnapshot.exists || !userSnapshot.exists) {
      throw new ProfileImageStateError();
    }

    const profile = userSnapshot.data() ?? {};
    assertMatchingProjection(
      profile,
      memberSnapshot.exists ? memberSnapshot.data() : undefined,
    );
    const revision = nextProfileImageRevision(profile.profileImageRevision);
    transaction.update(user, {
      profileImage: path,
      profileImageRevision: revision,
    });
    if (memberSnapshot.exists) {
      transaction.update(member, {
        profileImage: path,
        profileImageRevision: revision,
      });
    }
    return revision;
  });
}

type GenerationDeleteTarget = {
  delete(options: {
    ignoreNotFound: boolean;
    ifGenerationMatch: string;
  }): Promise<unknown>;
};

/** Deletes only this invocation's generation; a newer upload always wins. */
export async function deleteUploadedGenerationIfCurrent(
  target: GenerationDeleteTarget,
  uploadedGeneration: string,
): Promise<void> {
  try {
    await target.delete({
      ignoreNotFound: true,
      ifGenerationMatch: uploadedGeneration,
    });
  } catch (error) {
    // A concurrent upload replaced this generation. Its invocation (or the
    // account-deletion worker) owns cleanup of that newer object.
    const code = (error as { code?: unknown } | null)?.code;
    if (code !== 412 && code !== '412') throw error;
  }
}

async function deleteIfAccountClosing(
  uid: string,
  uploadedGeneration: string,
): Promise<boolean> {
  const db = getFirestore();
  const [lock, user] = await db.getAll(
    db.collection('accountDeletionLocks').doc(uid),
    db.collection('users').doc(uid),
  );
  if (!lock.exists && user.exists) return false;

  await deleteUploadedGenerationIfCurrent(
    getStorage().bucket().file(profileImagePathFor(uid)),
    uploadedGeneration,
  );
  return true;
}

/** Stores only a canonical private path; it never creates a download token. */
export async function uploadOwnProfileImage(
  uid: string,
  jpegBase64: unknown,
): Promise<{ path: string; revision: number }> {
  if (uid.length < 1 || uid.length > 128 || uid.includes('/')) {
    throw new ProfileImageStateError();
  }

  let authUser;
  try {
    authUser = await getAuth().getUser(uid);
  } catch (error) {
    if ((error as { code?: unknown } | null)?.code === 'auth/user-not-found') {
      throw new ProfileImageStateError();
    }
    throw error;
  }
  if (authUser.disabled || !authUser.emailVerified) {
    throw new ProfileImageStateError('verified-account-required');
  }

  const bytes = await sanitizeProfileImagePayload(jpegBase64);
  await assertProfileWritable(uid);

  const path = profileImagePathFor(uid);
  const bucket = getStorage().bucket();
  const file = bucket.file(path);
  let previous:
    | {
        bytes: Buffer;
        cacheControl: string;
        contentType: string;
        generation: string;
        metadata: Record<string, string | number | boolean | null>;
      }
    | undefined;
  try {
    const [metadata] = await file.getMetadata();
    const generation = String(metadata.generation);
    const size = Number(metadata.size);
    if (!generation || !Number.isSafeInteger(size) || size > maximumRollbackBytes) {
      throw new ProfileImageStateError('existing-avatar-cannot-be-backed-up');
    }
    const [previousBytes] = await bucket
      .file(path, { generation })
      .download();
    const customMetadata = { ...(metadata.metadata ?? {}) };
    delete customMetadata.firebaseStorageDownloadTokens;
    previous = {
      bytes: previousBytes,
      cacheControl: metadata.cacheControl ?? 'private, max-age=3600',
      contentType: metadata.contentType ?? 'image/jpeg',
      generation,
      metadata: customMetadata,
    };
  } catch (error) {
    const code = (error as { code?: unknown } | null)?.code;
    if (code !== 404 && code !== '404') throw error;
  }

  const uploadAttemptId = randomUUID();
  await file.save(bytes, {
    resumable: false,
    validation: 'crc32c',
    preconditionOpts: { ifGenerationMatch: previous?.generation ?? 0 },
    metadata: {
      contentType: 'image/jpeg',
      cacheControl: 'private, max-age=3600',
      metadata: { profileImageUploadAttempt: uploadAttemptId },
    },
  });
  // Resolve from GCS rather than file.metadata, which can be absent after save
  // or can still contain metadata read for the previous generation.
  const [uploadedMetadata] = await file.getMetadata();
  if (
    uploadedMetadata.metadata?.profileImageUploadAttempt !== uploadAttemptId
  ) {
    // Our generation has already been superseded, so there is no mutation from
    // this invocation left at the live canonical path to roll back.
    throw new ProfileImageStateError('uploaded-generation-superseded');
  }
  const uploadedGeneration = String(uploadedMetadata.generation ?? '');
  if (!uploadedGeneration) {
    throw new ProfileImageStateError('uploaded-generation-missing');
  }

  const restorePreviousObject = async (): Promise<void> => {
    try {
      if (previous == null) {
        await file.delete({
          ignoreNotFound: true,
          ifGenerationMatch: uploadedGeneration,
        });
        return;
      }
      await file.save(previous.bytes, {
        resumable: false,
        validation: 'crc32c',
        preconditionOpts: { ifGenerationMatch: uploadedGeneration },
        metadata: {
          contentType: previous.contentType,
          cacheControl: previous.cacheControl,
          metadata: previous.metadata,
        },
      });
    } catch (error) {
      // Another authorized upload won after this generation. Never overwrite
      // that newer object while rolling back this failed request.
      const code = (error as { code?: unknown } | null)?.code;
      if (code !== 412 && code !== '412') throw error;
    }
  };

  let revision: number;
  try {
    // GCS Admin uploads do not mint Firebase download tokens. Verify that fact
    // anyway, and revoke a stale custom token defensively before publishing
    // the path to either Firestore projection.
    const uploadedFile = bucket.file(path, { generation: uploadedGeneration });
    let [storedMetadata] = await uploadedFile.getMetadata();
    await file.setMetadata(
      {
        metadata: {
          firebaseStorageDownloadTokens: null,
          profileImageUploadAttempt: null,
        },
      },
      { ifGenerationMatch: uploadedGeneration },
    );
    [storedMetadata] = await uploadedFile.getMetadata();
    const remainingToken = storedMetadata.metadata
      ?.firebaseStorageDownloadTokens;
    if (
      typeof remainingToken === 'string' &&
      remainingToken.trim().length > 0
    ) {
      throw new ProfileImageStateError('download-token-not-revoked');
    }

    revision = await synchronizeProfileReference(uid, path);
  } catch (error) {
    if (!(await deleteIfAccountClosing(uid, uploadedGeneration))) {
      await restorePreviousObject();
    }
    throw error;
  }

  if (await deleteIfAccountClosing(uid, uploadedGeneration)) {
    throw new ProfileImageStateError();
  }
  return { path, revision };
}
