import 'dart:convert' show ascii;
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

Future<Uint8List> finalizePdfDocument(pw.Document document) async {
  final bytes = Uint8List.fromList(await document.save());
  validatePdfBytes(bytes);
  return bytes;
}

Uint8List copyPdfBytes(Uint8List bytes) {
  validatePdfBytes(bytes);
  return Uint8List.fromList(bytes);
}

void validatePdfBytes(Uint8List bytes) {
  if (bytes.length < 8) {
    throw const FormatException('PDF output is empty or truncated.');
  }

  final header = ascii.decode(bytes.sublist(0, 5), allowInvalid: true);
  if (header != '%PDF-') {
    throw const FormatException('PDF output has no valid header.');
  }

  final tailStart = bytes.length > 1024 ? bytes.length - 1024 : 0;
  final tail = ascii.decode(bytes.sublist(tailStart), allowInvalid: true);
  if (!tail.contains('%%EOF')) {
    throw const FormatException('PDF output has no end marker.');
  }
}
