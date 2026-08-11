import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves the file through an anchor download.
///
/// The Blob carries the MIME type so the browser and the operating system offer
/// it to the right application rather than guessing from the extension alone.
/// UTF-8 is explicit because the content carries German and Albanian
/// characters.
Future<void> downloadTextFile({
  required String contents,
  required String fileName,
  required String mimeType,
}) async {
  final bytes = Uint8List.fromList(utf8.encode(contents));
  final blob = web.Blob(
    <JSAny>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: '$mimeType;charset=utf-8'),
  );

  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = fileName;
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);

  try {
    anchor.click();
  } finally {
    anchor.remove();
    // The click captures the Blob synchronously, so releasing the URL here is
    // safe and avoids the leak that accumulates when it is never revoked.
    web.URL.revokeObjectURL(url);
  }
}
