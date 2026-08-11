const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const sharp = require('sharp');

const {
  InvalidProfileImageError,
  parseProfileImageUploadPayload,
  sanitizeProfileImagePayload,
} = require('../lib/profile_images');

function crc32(bytes) {
  let crc = 0xffffffff;
  for (const byte of bytes) {
    crc ^= byte;
    for (let bit = 0; bit < 8; bit += 1) {
      crc = (crc >>> 1) ^ (crc & 1 ? 0xedb88320 : 0);
    }
  }
  return (crc ^ 0xffffffff) >>> 0;
}

function pngTextChunk(keyword, text) {
  const type = Buffer.from('tEXt', 'ascii');
  const data = Buffer.from(`${keyword}\0${text}`, 'latin1');
  const chunk = Buffer.alloc(12 + data.length);
  chunk.writeUInt32BE(data.length, 0);
  type.copy(chunk, 4);
  data.copy(chunk, 8);
  chunk.writeUInt32BE(crc32(Buffer.concat([type, data])), 8 + data.length);
  return chunk;
}

async function jpeg({ width = 64, height = 32, metadata = false } = {}) {
  let image = sharp({
    create: {
      width,
      height,
      channels: 3,
      background: '#805ad5',
    },
  });
  if (metadata) {
    image = image.withExif({ IFD0: { Artist: 'private jpeg author' } });
  }
  return image.jpeg({ quality: 90 }).toBuffer();
}

async function png({ width = 32, height = 64, metadata = false } = {}) {
  let image = sharp({
    create: {
      width,
      height,
      channels: 4,
      background: '#2b6cb0',
    },
  });
  if (metadata) {
    image = image.withExif({ IFD0: { Artist: 'private png author' } });
  }
  return image.png().toBuffer();
}

describe('profile-image parser and sanitizer boundary', () => {
  it('exports the callable with App Check enforcement and bounded resources', () => {
    const https = require('firebase-functions/v2/https');
    const originalOnCall = https.onCall;
    const options = [];
    try {
      https.onCall = (callableOptions, handler) => {
        options.push(callableOptions);
        return originalOnCall(callableOptions, handler);
      };
      delete require.cache[require.resolve('../lib/index')];
      const { uploadProfileImage } = require('../lib/index');
      assert.equal(typeof uploadProfileImage, 'function');
    } finally {
      https.onCall = originalOnCall;
    }

    const profileImageOptions = options.find(
      (candidate) =>
        candidate.timeoutSeconds === 60 && candidate.memory === '512MiB',
    );
    assert.deepEqual(profileImageOptions, {
      region: 'europe-west4',
      timeoutSeconds: 60,
      memory: '512MiB',
      enforceAppCheck: true,
    });
  });

  it('accepts only exact revisioned JPEG and PNG request shapes', () => {
    assert.deepEqual(
      parseProfileImageUploadPayload({
        jpegBase64: 'YWJjZA==',
        expectedRevision: 7,
      }),
      {
        imageBase64: 'YWJjZA==',
        format: 'jpeg',
        expectedRevision: 7,
      },
    );
    assert.deepEqual(
      parseProfileImageUploadPayload({
        pngBase64: 'YWJjZA==',
        expectedRevision: 8,
      }),
      {
        imageBase64: 'YWJjZA==',
        format: 'png',
        expectedRevision: 8,
      },
    );

    for (const malformed of [
      { pngBase64: 'YWJjZA==' },
      { jpegBase64: 'YWJjZA==' },
      {
        jpegBase64: 'YWJjZA==',
        pngBase64: 'YWJjZA==',
        expectedRevision: 0,
      },
      {
        jpegBase64: 'YWJjZA==',
        expectedRevision: -1,
      },
      {
        jpegBase64: 'YWJjZA==',
        expectedRevision: 0,
        requestId: 'not-supported',
      },
    ]) {
      assert.throws(
        () => parseProfileImageUploadPayload(malformed),
        InvalidProfileImageError,
      );
    }
  });

  it('accepts valid JPEG and PNG content, re-encodes JPEG and strips metadata', async () => {
    for (const [format, input] of [
      ['jpeg', await jpeg({ metadata: true })],
      ['png', await png({ metadata: true })],
    ]) {
      const sourceMetadata = await sharp(input).metadata();
      assert.ok(sourceMetadata.exif, `${format} fixture must contain metadata`);

      const output = await sanitizeProfileImagePayload(
        input.toString('base64'),
        format,
      );
      const outputMetadata = await sharp(output).metadata();
      assert.equal(outputMetadata.format, 'jpeg', format);
      assert.equal(outputMetadata.exif, undefined, format);
      assert.equal(outputMetadata.icc, undefined, format);
      assert.equal(outputMetadata.xmp, undefined, format);
    }
  });

  it('fails closed when the declared JPEG/PNG discriminator mismatches decoded content', async () => {
    const jpegBytes = await jpeg();
    const pngBytes = await png();
    await assert.rejects(
      sanitizeProfileImagePayload(jpegBytes.toString('base64'), 'png'),
      InvalidProfileImageError,
    );
    await assert.rejects(
      sanitizeProfileImagePayload(pngBytes.toString('base64'), 'jpeg'),
      InvalidProfileImageError,
    );
  });

  it('rejects malformed, non-canonical and oversized payloads', async () => {
    for (const malformed of [
      '',
      'not base64',
      'YWJjZA==\n',
      Buffer.from([0xff, 0xd8, 0xff, 0xd9]).toString('base64'),
      Buffer.from([0x89, 0x50, 0x4e, 0x47]).toString('base64'),
    ]) {
      await assert.rejects(
        sanitizeProfileImagePayload(malformed),
        InvalidProfileImageError,
      );
    }

    const overCeiling = Buffer.alloc(5 * 1024 * 1024 + 1);
    await assert.rejects(
      sanitizeProfileImagePayload(overCeiling.toString('base64')),
      InvalidProfileImageError,
    );
  });

  it('rejects either dimension above 1024 instead of silently resizing it', async () => {
    for (const input of [
      await jpeg({ width: 1025, height: 16 }),
      await jpeg({ width: 16, height: 1025 }),
    ]) {
      await assert.rejects(
        sanitizeProfileImagePayload(input.toString('base64'), 'jpeg'),
        InvalidProfileImageError,
      );
    }
  });

  it('rejects embedded JPEG and PNG control/polyglot payloads', async () => {
    const jpegBytes = await jpeg();
    const jpegControl = Buffer.concat([
      jpegBytes.subarray(0, jpegBytes.length - 2),
      Buffer.from('\n<script>alert(1)</script>\n', 'ascii'),
      Buffer.from([0xff, 0xd9]),
    ]);
    await assert.rejects(
      sanitizeProfileImagePayload(jpegControl.toString('base64'), 'jpeg'),
      InvalidProfileImageError,
    );

    const pngBytes = await png();
    const iendOffset = pngBytes.length - 12;
    const pngControl = Buffer.concat([
      pngBytes.subarray(0, iendOffset),
      pngTextChunk('Comment', '<script>alert(1)</script>'),
      pngBytes.subarray(iendOffset),
    ]);
    assert.equal((await sharp(pngControl).metadata()).format, 'png');
    await assert.rejects(
      sanitizeProfileImagePayload(pngControl.toString('base64'), 'png'),
      InvalidProfileImageError,
    );
  });
});
