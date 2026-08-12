import { getAuth } from 'firebase-admin/auth';
import {
  DocumentReference,
  getFirestore,
  Transaction,
} from 'firebase-admin/firestore';
import { getStorage } from 'firebase-admin/storage';
import { randomUUID } from 'node:crypto';
import sharp = require('sharp');

const maximumInputBytes = 5 * 1024 * 1024;
const maximumRollbackBytes = 15 * 1024 * 1024;
const maximumDimension = 1024;
const maximumBase64Length = Math.ceil(maximumInputBytes / 3) * 4;
const maximumProfileImageRevision = 2_147_483_647;

export const profileImagePathFor = (uid: string): string =>
  `profile_images/${uid}/avatar.jpg`;

export class InvalidProfileImageError extends Error {
  constructor(message = 'invalid-profile-image') {
    super(message);
    this.name = 'InvalidProfileImageError';
  }
}

export class ProfileImageStateError extends Error {
  constructor(message = 'profile-unavailable') {
    super(message);
    this.name = 'ProfileImageStateError';
  }
}

export class ProfileImageAuthorizationError extends Error {
  constructor(message: 'company-banned' | 'company-membership-inactive') {
    super(message);
    this.name = 'ProfileImageAuthorizationError';
  }
}

export class ProfileImageRevisionError extends Error {
  constructor() {
    super('stale-profile-image-revision');
    this.name = 'ProfileImageRevisionError';
  }
}

export type ProfileImageInputFormat = 'jpeg' | 'png';

export type ParsedProfileImageUpload = {
  imageBase64: string;
  format: ProfileImageInputFormat;
  expectedRevision: number;
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function hasExactlyKeys(
  value: Record<string, unknown>,
  expected: readonly string[],
): boolean {
  const actual = Object.keys(value).sort();
  const wanted = [...expected].sort();
  return (
    actual.length === wanted.length &&
    actual.every((key, index) => key === wanted[index])
  );
}

export function parseProfileImageUploadPayload(
  raw: unknown,
): ParsedProfileImageUpload {
  if (!isRecord(raw)) throw new InvalidProfileImageError('profile-image-request-invalid');

  const format = Object.prototype.hasOwnProperty.call(raw, 'jpegBase64')
    ? 'jpeg'
    : Object.prototype.hasOwnProperty.call(raw, 'pngBase64')
      ? 'png'
      : null;
  const formatKey = format === 'jpeg' ? 'jpegBase64' : 'pngBase64';
  if (
    format == null ||
    !hasExactlyKeys(raw, [formatKey, 'expectedRevision']) ||
    typeof raw[formatKey] !== 'string' ||
    !Number.isInteger(raw.expectedRevision) ||
    (raw.expectedRevision as number) < 0 ||
    (raw.expectedRevision as number) > maximumProfileImageRevision
  ) {
    throw new InvalidProfileImageError('profile-image-request-invalid');
  }
  return {
    imageBase64: raw[formatKey] as string,
    format,
    expectedRevision: raw.expectedRevision as number,
  };
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

const forbiddenEmbeddedPayloads = [
  Buffer.from('<script', 'ascii'),
  Buffer.from('</script', 'ascii'),
  Buffer.from('javascript:', 'ascii'),
  Buffer.from('<!doctype', 'ascii'),
  Buffer.from('<html', 'ascii'),
  Buffer.from('%pdf-', 'ascii'),
  Buffer.from([0x70, 0x6b, 0x03, 0x04]),
];

function containsForbiddenEmbeddedPayload(input: Buffer): boolean {
  const lower = Buffer.from(input.toString('latin1').toLowerCase(), 'latin1');
  return forbiddenEmbeddedPayloads.some((signature) =>
    lower.includes(signature),
  );
}

function decodedImageFormat(input: Buffer): ProfileImageInputFormat {
  if (containsForbiddenEmbeddedPayload(input)) return invalidImage();

  if (
    input.length >= 4 &&
    input[0] === 0xff &&
    input[1] === 0xd8 &&
    input[2] === 0xff &&
    input[input.length - 2] === 0xff &&
    input[input.length - 1] === 0xd9
  ) {
    return 'jpeg';
  }

  const pngSignature = Buffer.from([
    0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a,
  ]);
  const pngEnd = Buffer.from([
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44,
    0xae, 0x42, 0x60, 0x82,
  ]);
  if (
    input.length >= pngSignature.length + pngEnd.length &&
    input.subarray(0, pngSignature.length).equals(pngSignature) &&
    input.subarray(-pngEnd.length).equals(pngEnd)
  ) {
    return 'png';
  }
  return invalidImage();
}

export async function sanitizeProfileImagePayload(
  imageBase64: unknown,
  expectedFormat: ProfileImageInputFormat = 'jpeg',
): Promise<Buffer> {
  if (
    typeof imageBase64 !== 'string' ||
    imageBase64.length === 0 ||
    imageBase64.length > maximumBase64Length ||
    imageBase64.length % 4 !== 0 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(imageBase64)
  ) {
    return invalidImage();
  }

  const input = Buffer.from(imageBase64, 'base64');
  if (
    input.length === 0 ||
    input.length > maximumInputBytes ||
    input.toString('base64') !== imageBase64 ||
    input.length < 4
  ) {
    return invalidImage();
  }

  const decodedFormat = decodedImageFormat(input);
  if (decodedFormat !== expectedFormat) return invalidImage();

  try {
    const image = sharp(input, {
      failOn: 'warning',
      limitInputPixels: 40 * 1024 * 1024,
      sequentialRead: true,
    });
    const metadata = await image.metadata();
    if (
      metadata.format !== decodedFormat ||
      metadata.width == null ||
      metadata.height == null ||
      metadata.width < 1 ||
      metadata.height < 1 ||
      metadata.width > maximumDimension ||
      metadata.height > maximumDimension ||
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
      output.length > maximumInputBytes ||
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
): { companyId: string; revision: number; membership: unknown } {
  const companyId =
    typeof profile.companyId === 'string' ? profile.companyId.trim() : '';
  if (
    companyId.length === 0 ||
    companyId.length > 128 ||
    companyId.includes('/') ||
    profile.companyId !== companyId
  ) {
    throw new ProfileImageStateError('company-membership-unavailable');
  }

  const storedRevision = profile.profileImageRevision;
  const revision = storedRevision ?? 0;
  if (
    !Number.isInteger(revision) ||
    (revision as number) < 0 ||
    (revision as number) > maximumProfileImageRevision
  ) {
    throw new ProfileImageStateError('profile-revision-unavailable');
  }

  const membership = profile.membership;
  if (
    member == null ||
    !hasOnlyProjectionFields(member) ||
    member.fullName !== profile.fullName ||
    member.companyId !== profile.companyId ||
    member.role !== profile.role ||
    member.membership !== membership ||
    member.profileImage !== profile.profileImage ||
    member.profileImageRevision !== storedRevision
  ) {
    throw new ProfileImageStateError('member-projection-mismatch');
  }
  return { companyId, revision: revision as number, membership };
}

type WritableProfileState = {
  profile: Record<string, unknown>;
  revision: number;
  user: DocumentReference;
  member: DocumentReference;
};

async function writableProfileState(
  uid: string,
  transaction: Transaction,
): Promise<WritableProfileState> {
  const db = getFirestore();
  const user = db.collection('users').doc(uid);
  const member = db.collection('memberDirectory').doc(uid);
  const lock = db.collection('accountDeletionLocks').doc(uid);
  const [lockSnapshot, userSnapshot, memberSnapshot] = await transaction.getAll(
    lock,
    user,
    member,
  );
  if (lockSnapshot.exists || !userSnapshot.exists) {
    throw new ProfileImageStateError('profile-unavailable');
  }

  const profile = userSnapshot.data() ?? {};
  const projection = assertMatchingProjection(
    profile,
    memberSnapshot.exists ? memberSnapshot.data() : undefined,
  );
  const company = db.collection('companies').doc(projection.companyId);
  const ban = company.collection('bans').doc(uid);
  const [companySnapshot, banSnapshot] = await transaction.getAll(company, ban);
  if (!companySnapshot.exists) {
    throw new ProfileImageStateError('company-unavailable');
  }
  const companyData = companySnapshot.data() ?? {};
  if (Object.prototype.hasOwnProperty.call(companyData, 'deletionScheduledFor')) {
    throw new ProfileImageStateError('company-closing');
  }
  if (banSnapshot.exists) {
    throw new ProfileImageAuthorizationError('company-banned');
  }
  if (projection.membership !== 'active') {
    throw new ProfileImageAuthorizationError('company-membership-inactive');
  }
  return {
    profile,
    revision: projection.revision,
    user,
    member,
  };
}

async function assertExpectedRevision(
  uid: string,
  expectedRevision: number,
): Promise<void> {
  const db = getFirestore();
  await db.runTransaction(async (transaction: Transaction) => {
    const state = await writableProfileState(uid, transaction);
    if (state.revision !== expectedRevision) {
      throw new ProfileImageRevisionError();
    }
    nextProfileImageRevision(state.revision);
  });
}

async function synchronizeProfileReference(
  uid: string,
  path: string,
  expectedRevision: number,
): Promise<number> {
  const db = getFirestore();

  return db.runTransaction(async (transaction: Transaction) => {
    const state = await writableProfileState(uid, transaction);
    if (state.revision !== expectedRevision) {
      throw new ProfileImageRevisionError();
    }

    const revision = nextProfileImageRevision(state.revision);
    transaction.update(state.user, {
      profileImage: path,
      profileImageRevision: revision,
    });
    transaction.update(state.member, {
      profileImage: path,
      profileImageRevision: revision,
    });
    return revision;
  });
}

type GenerationDeleteTarget = {
  delete(options: {
    ignoreNotFound: boolean;
    ifGenerationMatch: string;
  }): Promise<unknown>;
};

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

export async function uploadOwnProfileImage(
  uid: string,
  upload: ParsedProfileImageUpload,
): Promise<{ path: string; revision: number }> {
  if (uid.length < 1 || uid.length > 128 || uid.includes('/')) {
    throw new ProfileImageStateError('profile-unavailable');
  }

  let authUser;
  try {
    authUser = await getAuth().getUser(uid);
  } catch (error) {
    if ((error as { code?: unknown } | null)?.code === 'auth/user-not-found') {
      throw new ProfileImageStateError('profile-unavailable');
    }
    throw error;
  }
  if (authUser.disabled || !authUser.emailVerified) {
    throw new ProfileImageStateError('verified-account-required');
  }

  const bytes = await sanitizeProfileImagePayload(
    upload.imageBase64,
    upload.format,
  );
  const path = profileImagePathFor(uid);
  await assertExpectedRevision(uid, upload.expectedRevision);

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
    delete customMetadata.profileImageUploadAttempt;
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
  try {
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
  } catch (error) {
    const code = (error as { code?: unknown } | null)?.code;
    if (code === 412 || code === '412') {
      throw new ProfileImageRevisionError();
    }
    throw error;
  }

  const [uploadedMetadata] = await file.getMetadata();
  if (
    uploadedMetadata.metadata?.profileImageUploadAttempt !== uploadAttemptId
  ) {
    throw new ProfileImageRevisionError();
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
      const code = (error as { code?: unknown } | null)?.code;
      if (code !== 412 && code !== '412') throw error;
    }
  };

  let revision: number;
  try {
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

    revision = await synchronizeProfileReference(
      uid,
      path,
      upload.expectedRevision,
    );
  } catch (error) {
    if (!(await deleteIfAccountClosing(uid, uploadedGeneration))) {
      await restorePreviousObject();
    }
    throw error;
  }

  if (await deleteIfAccountClosing(uid, uploadedGeneration)) {
    throw new ProfileImageStateError('profile-unavailable');
  }
  return { path, revision };
}
