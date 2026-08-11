import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands the file to the platform share sheet.
///
/// The MIME type is set explicitly so Android offers the applications that can
/// actually open it rather than resolving from the extension alone.
/// `XFile.fromData` ignores its `name` argument on non-web platforms, so the
/// file name travels through `fileNameOverrides` instead - without it the
/// shared attachment arrives with a generated name and no suffix.
Future<void> downloadTextFile({
  required String contents,
  required String fileName,
  required String mimeType,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(contents));
  await Share.shareXFiles(
    [XFile.fromData(bytes, mimeType: mimeType)],
    fileNameOverrides: [fileName],
  );
}
