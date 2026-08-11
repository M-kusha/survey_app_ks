import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the live answer screen labels its timer as UI-only in every locale', () {
    final source = File(
      'lib/survey_pages/user_survey/survey_answer_page.dart',
    ).readAsStringSync();

    expect(source, contains('if (_isTimed) ...['));
    expect(source, contains("'question_timer_ux_only'.tr()"));

    const expected = {
      'en':
          'Screen timer only — it moves to the next question, but is not a submission deadline.',
      'de':
          'Nur Bildschirm-Timer – er wechselt zur nächsten Frage, ist aber keine Abgabefrist.',
      'sq':
          'Vetëm kohëmatës në ekran — kalon te pyetja tjetër, por nuk është afat dorëzimi.',
    };

    for (final entry in expected.entries) {
      final translations =
          jsonDecode(
                File(
                  'assets/translations/${entry.key}.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(translations['question_timer_ux_only'], entry.value);
    }
  });
}
