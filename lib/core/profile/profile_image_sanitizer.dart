import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

const _maximumInputBytes = 15 * 1024 * 1024;
const _maximumDimension = 1024;

class InvalidProfileImage implements Exception {
  const InvalidProfileImage();
}

Future<Uint8List> sanitizeProfileImage(XFile picked) async {
  final bytes = await picked.readAsBytes();
  if (bytes.isEmpty || bytes.length > _maximumInputBytes) {
    throw const InvalidProfileImage();
  }

  return compute(sanitizeProfileImageBytes, bytes);
}

@visibleForTesting
Uint8List sanitizeProfileImageBytes(Uint8List bytes) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(bytes);
  } catch (_) {
    throw const InvalidProfileImage();
  }
  if (decoded == null || decoded.width < 1 || decoded.height < 1) {
    throw const InvalidProfileImage();
  }

  decoded = image.bakeOrientation(decoded);
  if (decoded.width > _maximumDimension || decoded.height > _maximumDimension) {
    decoded = decoded.width >= decoded.height
        ? image.copyResize(
            decoded,
            width: _maximumDimension,
            interpolation: image.Interpolation.average,
          )
        : image.copyResize(
            decoded,
            height: _maximumDimension,
            interpolation: image.Interpolation.average,
          );
  }

  decoded.exif = image.ExifData();
  decoded.iccProfile = null;
  decoded.textData = null;

  final encoded = image.encodeJpg(decoded, quality: 85);
  if (encoded.isEmpty || encoded.length >= 5 * 1024 * 1024) {
    throw const InvalidProfileImage();
  }
  return encoded;
}
