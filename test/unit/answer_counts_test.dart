import 'package:echomeet/survey_pages/admin/survey_analytics.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> choice(List<String> options) => {
  'type': 'Single',
  'question': 'Q',
  'options': options,
};

Map<String, dynamic> freeText() => {'type': 'Text', 'question': 'Q'};

Participant answering(Map<int, List<int>> byQuestion, {String id = 'u'}) =>
    Participant(
      userId: id,
      name: 'Someone',
      surveyAnswers: {
        for (final entry in byQuestion.entries)
          SurveyScorer.answerKey(entry.key): entry.value,
      },
      score: 0,
      textAnswersReviewed: const {},
    );

void main() {
  test('counts a pick against its option', () {
    final counts = countAnswers(
      [
        choice(['A', 'B']),
      ],
      [
        answering({
          0: [0],
        }, id: 'a'),
        answering({
          0: [1],
        }, id: 'b'),
        answering({
          0: [1],
        }, id: 'c'),
      ],
    );

    expect(counts, [
      [1, 2],
    ]);
  });

  test('a text question contributes an empty row rather than crashing', () {
    // The old code called `questionData['options'].length` for every question,
    // so a single text question threw and took the whole analytics screen with
    // it — for any survey that had one.
    final counts = countAnswers(
      [
        choice(['A', 'B']),
        freeText(),
      ],
      [
        answering({
          0: [0],
          1: [],
        }),
      ],
    );

    expect(counts, hasLength(2));
    expect(counts[1], isEmpty);
  });

  test('a multiple-choice answer counts against every option picked', () {
    final counts = countAnswers(
      [
        choice(['A', 'B', 'C']),
      ],
      [
        answering({
          0: [0, 2],
        }),
      ],
    );

    expect(counts, [
      [1, 0, 1],
    ]);
  });

  test('an index outside the options is dropped, not counted', () {
    // An admin can delete an option after people have answered, which leaves
    // stored answers pointing past the end of the list.
    final counts = countAnswers(
      [
        choice(['A', 'B']),
      ],
      [
        answering({
          0: [5],
        }),
      ],
    );

    expect(counts, [
      [0, 0],
    ]);
  });

  test('a question nobody reached counts as zeros', () {
    final counts = countAnswers(
      [
        choice(['A', 'B']),
        choice(['C', 'D']),
      ],
      [
        answering({
          0: [0],
        }),
      ],
    );

    expect(counts[1], [0, 0]);
  });

  test('no participants gives a row of zeros per question', () {
    final counts = countAnswers([
      choice(['A', 'B']),
    ], []);
    expect(counts, [
      [0, 0],
    ]);
  });

  test('a question with no options at all is safe', () {
    final counts = countAnswers(
      [choice(const [])],
      [
        answering({
          0: [0],
        }),
      ],
    );
    expect(counts.single, isEmpty);
  });
}
