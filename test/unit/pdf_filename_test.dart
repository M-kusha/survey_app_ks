import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// Export file names.
///
/// `PdfPreview` defaults to `document.pdf`, so every export anyone downloaded
/// landed under the same name as the last one. Survey titles are free text and
/// go straight into that name, which is where the escaping matters.
void main() {
  test('joins the parts with hyphens', () {
    expect(
      pdfFileNameFrom(['Q1 Engagement', 'Alice Smith']),
      'Q1-Engagement-Alice-Smith',
    );
  });

  test('strips characters that are path separators', () {
    // A slash in a survey title is a directory on every platform this ships to.
    expect(
      pdfFileNameFrom(['Sales / Marketing', 'Bob']),
      'Sales-Marketing-Bob',
    );
  });

  test('drops punctuation rather than encoding it', () {
    expect(pdfFileNameFrom(['Team "Alpha"?!']), 'Team-Alpha');
  });

  test('collapses runs of whitespace', () {
    expect(pdfFileNameFrom(['  spaced   out  ']), 'spaced-out');
  });

  test('skips parts that are empty once cleaned', () {
    expect(pdfFileNameFrom(['Survey', '', '???']), 'Survey');
  });

  test('falls back rather than producing an empty name', () {
    // A survey titled entirely in punctuation is unlikely but a file called
    // ".pdf" is worse than a dull one.
    expect(pdfFileNameFrom(['***', '']), 'echomeet-export');
    expect(pdfFileNameFrom([]), 'echomeet-export');
  });

  test('caps the length for the filesystem', () {
    final name = pdfFileNameFrom([List.filled(40, 'long').join(' ')]);
    expect(name.length, lessThanOrEqualTo(80));
  });

  test('keeps digits and underscores', () {
    expect(pdfFileNameFrom(['q1_2025 results']), 'q1_2025-results');
  });
}
