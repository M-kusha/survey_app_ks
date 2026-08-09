import 'package:echomeet/survey_pages/utilities/survey_answer_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits publishable questions from immutable grading keys', () {
    final source = <Map<String, dynamic>>[
      {
        'type': 'Single',
        'question': 'Pick one',
        'options': ['A', 'B'],
        'correctAnswer': 1,
      },
      {
        'type': 'Multiple',
        'question': 'Pick two',
        'options': ['A', 'B', 'C'],
        'correctAnswers': [0, 2],
      },
      {'type': 'Text', 'question': 'Explain'},
    ];

    final split = splitSurveyQuestions(source);

    for (final question in split.publicQuestions) {
      expect(question, isNot(contains('correctAnswer')));
      expect(question, isNot(contains('correctAnswers')));
    }
    expect(split.privateAnswerKeys, [
      {'type': 'Single', 'correctAnswer': 1},
      {
        'type': 'Multiple',
        'correctAnswers': [0, 2],
      },
      {'type': 'Text'},
    ]);

    // Splitting must not mutate the editor state before navigation completes.
    expect(source.first['correctAnswer'], 1);
    expect(source[1]['correctAnswers'], [0, 2]);
  });

  test('does not invent grading material for an ordinary survey question', () {
    final split = splitSurveyQuestions([
      {
        'type': 'Multiple',
        'question': 'Select any option',
        'options': ['A', 'B'],
      },
    ]);

    expect(split.privateAnswerKeys, [
      {'type': 'Multiple'},
    ]);
  });
}
