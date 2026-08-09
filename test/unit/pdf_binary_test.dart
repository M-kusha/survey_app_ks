import 'dart:typed_data';

import 'package:echomeet/survey_pages/admin/print_pages/pdf_binary.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test(
    'finalized PDF bytes produce separate preview and download copies',
    () async {
      final document = pw.Document()
        ..addPage(pw.Page(build: (_) => pw.SizedBox()));

      final bytes = await finalizePdfDocument(document);
      final previewBytes = copyPdfBytes(bytes);
      final downloadBytes = copyPdfBytes(bytes);

      expect(previewBytes, orderedEquals(bytes));
      expect(downloadBytes, orderedEquals(bytes));
      expect(identical(previewBytes, bytes), isFalse);
      expect(identical(downloadBytes, bytes), isFalse);
      previewBytes[0] = 0;
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      expect(String.fromCharCodes(downloadBytes.take(5)), '%PDF-');
      expect(
        String.fromCharCodes(
          bytes.skip(bytes.length > 1024 ? bytes.length - 1024 : 0),
        ),
        contains('%%EOF'),
      );
    },
  );

  test('rejects empty and truncated PDF payloads before transfer', () {
    expect(
      () => validatePdfBytes(Uint8List(0)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => validatePdfBytes(Uint8List.fromList('%PDF-1.7'.codeUnits)),
      throwsA(isA<FormatException>()),
    );
  });
}
