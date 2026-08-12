import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

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
