import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

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
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName;
  anchor.style.display = 'none';
  web.document.body!.appendChild(anchor);

  try {
    anchor.click();
  } finally {
    anchor.remove();

    web.URL.revokeObjectURL(url);
  }
}
