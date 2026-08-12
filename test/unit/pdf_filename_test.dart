import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('joins the parts with hyphens', () {
    expect(
      pdfFileNameFrom(['Q1 Engagement', 'Alice Smith']),
      'Q1-Engagement-Alice-Smith',
    );
  });

  test('strips characters that are path separators', () {
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
