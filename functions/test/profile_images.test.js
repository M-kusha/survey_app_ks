const assert = require('node:assert/strict');
const { describe, it } = require('node:test');
const sharp = require('sharp');

const {
  InvalidProfileImageError,
  ProfileImageStateError,
  deleteUploadedGenerationIfCurrent,
  nextProfileImageRevision,
  profileImagePathFor,
  sanitizeProfileImagePayload,
} = require('../lib/profile_images');

describe('trusted profile image sanitizer', () => {
  it('derives the only writable path from the authenticated uid', () => {
    assert.equal(
      profileImagePathFor('owner-123'),
      'profile_images/owner-123/avatar.jpg',
    );
  });

  it('increments the trusted refresh revision and fails closed at invalid bounds', () => {
    assert.equal(nextProfileImageRevision(undefined), 1);
    assert.equal(nextProfileImageRevision(7), 8);
    assert.throws(() => nextProfileImageRevision(-1), ProfileImageStateError);
    assert.throws(
      () => nextProfileImageRevision(2_147_483_647),
      ProfileImageStateError,
    );
  });

  it('cleans up only its own generation and treats a concurrent 412 as success', async () => {
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

    await assert.rejects(
      deleteUploadedGenerationIfCurrent(
        {
          delete: async () => {
            throw new Error('storage-unavailable');
          },
        },
        'generation-a',
      ),
      /storage-unavailable/,
    );
  });

  it('re-encodes a JPEG, strips metadata and bounds its dimensions', async () => {
    const input = await sharp({
      create: {
        width: 1600,
        height: 800,
        channels: 3,
        background: '#8a5cf5',
      },
    })
      .withExif({ IFD0: { Artist: 'hidden author' } })
      .jpeg({ quality: 90 })
      .toBuffer();
    assert.ok((await sharp(input).metadata()).exif);

    const output = await sanitizeProfileImagePayload(input.toString('base64'));
    const metadata = await sharp(output).metadata();
    assert.equal(metadata.format, 'jpeg');
    assert.equal(metadata.width, 1024);
    assert.equal(metadata.height, 512);
    assert.equal(metadata.exif, undefined);
    assert.equal(metadata.icc, undefined);
    assert.equal(metadata.xmp, undefined);
  });

  it('rejects non-canonical base64 and non-JPEG bytes', async () => {
    await assert.rejects(
      sanitizeProfileImagePayload('not base64'),
      InvalidProfileImageError,
    );
    await assert.rejects(
      sanitizeProfileImagePayload('YWJjZA==\n'),
      InvalidProfileImageError,
    );

    const png = await sharp({
      create: {
        width: 2,
        height: 2,
        channels: 3,
        background: '#000000',
      },
    })
      .png()
      .toBuffer();
    await assert.rejects(
      sanitizeProfileImagePayload(png.toString('base64')),
      InvalidProfileImageError,
    );
  });

  it('rejects a decoded payload at the five MiB ceiling', async () => {
    const tooLarge = Buffer.alloc(5 * 1024 * 1024);
    tooLarge[0] = 0xff;
    tooLarge[1] = 0xd8;
    tooLarge[2] = 0xff;
    tooLarge[tooLarge.length - 2] = 0xff;
    tooLarge[tooLarge.length - 1] = 0xd9;
    await assert.rejects(
      sanitizeProfileImagePayload(tooLarge.toString('base64')),
      InvalidProfileImageError,
    );
  });
});
