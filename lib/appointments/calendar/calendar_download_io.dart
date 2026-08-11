import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Hands the calendar file to the platform share sheet.
///
/// `text/calendar` is set explicitly so Android offers calendar applications
/// rather than resolving from the extension alone. `XFile.fromData` ignores its
/// `name` argument on non-web platforms, so the file name travels through
/// `fileNameOverrides` instead - without it the shared attachment arrives with
/// a generated name and no `.ics` suffix.
Future<void> downloadCalendarFile({
  required String contents,
  required String fileName,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(contents));
  await Share.shareXFiles(
    [XFile.fromData(bytes, mimeType: 'text/calendar')],
    fileNameOverrides: [fileName],
  );
}
