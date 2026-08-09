import 'dart:typed_data';

import 'package:echomeet/core/profile/profile_image_sanitizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;

void main() {
  test('re-encodes, downsizes, and removes private metadata', () {
    final source = image.Image(width: 2048, height: 1024);
    image.fill(source, color: image.ColorRgb8(30, 90, 180));
    source.exif.imageIfd.make = 'PRIVATE-CAMERA';
    source.exif.gpsIfd.setGpsLocation(latitude: 52.52, longitude: 13.405);
    source.textData = {'Comment': 'PRIVATE-COMMENT'};

    final result = sanitizeProfileImageBytes(image.encodeJpg(source));
    final decoded = image.decodeJpg(result)!;

    expect(decoded.width, 1024);
    expect(decoded.height, 512);
    expect(decoded.exif.imageIfd.make, isNull);
    expect(decoded.exif.gpsIfd.gpsLatitude, isNull);
    expect(decoded.textData, isNull);
    expect(String.fromCharCodes(result), isNot(contains('PRIVATE-')));
  });

  test('rejects data that is not an image', () {
    expect(
      () => sanitizeProfileImageBytes(Uint8List.fromList([1, 2, 3])),
      throwsA(isA<InvalidProfileImage>()),
    );
  });
}
