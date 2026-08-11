import 'package:echomeet/survey_pages/utilities/survey_answer_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads option indexes from a canonical protected key', () {
    expect(
      readAnswerKeyIndexes({
        'questionKeys': [
          {'type': 'Single', 'correctAnswer': 1},
          {
            'type': 'Multiple',
            'correctAnswers': [0, 2],
          },
          {'type': 'Text'},
        ],
      }),
      [
        {1},
        {0, 2},
        <int>{},
      ],
    );
  });

  test('fails closed on absent or malformed protected keys', () {
    expect(readAnswerKeyIndexes(null), isEmpty);
    expect(readAnswerKeyIndexes({'questionKeys': 'not-a-list'}), isEmpty);
    expect(
      readAnswerKeyIndexes({
        'questionKeys': [
          {'type': 'Single', 'correctAnswer': 'one'},
          {
            'type': 'Multiple',
            'correctAnswers': [0, 'two'],
          },
          'not-a-map',
        ],
      }),
      [
        <int>{},
        {0},
        <int>{},
      ],
    );
  });
}
