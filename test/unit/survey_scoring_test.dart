import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builders keep each test focused on the rule it is exercising rather than on
/// the shape of the stored question map.
Map<String, dynamic> single(String correct, {List<String>? options}) => {
  'type': 'Single',
  'question': 'q',
  'options': options ?? const ['a', 'b', 'c', 'd'],
  'correctAnswer': correct,
};

Map<String, dynamic> multiple(List<String> correct, {List<String>? options}) =>
    {
      'type': 'Multiple',
      'question': 'q',
      'options': options ?? const ['a', 'b', 'c', 'd'],
      'correctAnswers': correct,
    };

Map<String, dynamic> text() => {
  'type': 'Text',
  'question': 'q',
  'options': const <String>[],
};

const surveyId = 'SURVEY1';

SurveyGrade gradeOf(
  List<Map<String, dynamic>> questions,
  List<List<dynamic>> answers, {
  Map<String, bool> reviews = const {},
}) => SurveyScorer.grade(
  surveyId: surveyId,
  questions: questions,
  answers: {
    for (var i = 0; i < answers.length; i++)
      SurveyScorer.answerKey(i): answers[i],
  },
  textReviews: reviews,
);

void main() {
  group('single choice', () {
    test('the correct option earns full marks', () {
      final grade = gradeOf(
        [single('a')],
        [
          ['a'],
        ],
      );
      expect(grade.percentage, 100);
      expect(grade.correctCount, 1);
    });

    test('a wrong option earns nothing', () {
      final grade = gradeOf(
        [single('a')],
        [
          ['b'],
        ],
      );
      expect(grade.percentage, 0);
      expect(grade.correctCount, 0);
    });

    test('an unanswered question earns nothing but still counts', () {
      final grade = gradeOf([single('a')], [[]]);
      expect(grade.percentage, 0);
      expect(grade.gradedCount, 1);
    });
  });

  group('multiple choice', () {
    test('the exact correct set earns full marks', () {
      final grade = gradeOf(
        [
          multiple(['a', 'b']),
        ],
        [
          ['a', 'b'],
        ],
      );
      expect(grade.percentage, 100);
      expect(grade.correctCount, 1);
    });

    // The regression this whole file exists for: intersection-only scoring gave
    // full marks to anyone who simply ticked every box.
    test('selecting every option scores zero, not full marks', () {
      final grade = gradeOf(
        [
          multiple(['a', 'b']),
        ],
        [
          ['a', 'b', 'c', 'd'],
        ],
      );
      expect(grade.percentage, 0);
      expect(grade.correctCount, 0);
    });

    test('one right and one wrong cancel out', () {
      final grade = gradeOf(
        [
          multiple(['a', 'b']),
        ],
        [
          ['a', 'c'],
        ],
      );
      expect(grade.percentage, 0);
    });

    test('a correct subset earns partial credit but is not "correct"', () {
      final grade = gradeOf(
        [
          multiple(['a', 'b']),
        ],
        [
          ['a'],
        ],
      );
      expect(grade.percentage, 50);
      expect(grade.correctCount, 0, reason: 'partial credit is not full marks');
    });

    test('credit never goes negative and cannot drag down other questions', () {
      final grade = gradeOf(
        [
          multiple(['a']),
          single('a'),
        ],
        [
          ['b', 'c', 'd'],
          ['a'],
        ],
      );
      expect(grade.questions.first.credit, 0);
      expect(grade.percentage, 50);
    });

    test('a question authored with no correct answers is excluded', () {
      final grade = gradeOf(
        [multiple([]), single('a')],
        [
          ['a'],
          ['a'],
        ],
      );
      expect(grade.gradedCount, 1);
      expect(grade.percentage, 100);
    });
  });

  group('free-text questions', () {
    test('an unreviewed answer is excluded from the denominator', () {
      final grade = gradeOf(
        [single('a'), text()],
        [
          ['a'],
          ['anything'],
        ],
      );
      expect(grade.gradedCount, 1);
      expect(
        grade.percentage,
        100,
        reason: '100% must be reachable while review is outstanding',
      );
      expect(grade.hasPendingReview, isTrue);
    });

    test('a reviewer marking it correct counts it', () {
      final grade = gradeOf(
        [single('a'), text()],
        [
          ['b'],
          ['anything'],
        ],
        reviews: {SurveyScorer.reviewKey(surveyId, 1): true},
      );
      expect(grade.gradedCount, 2);
      expect(grade.percentage, 50);
      expect(grade.hasPendingReview, isFalse);
    });

    test('a reviewer marking it wrong is distinct from not reviewing it', () {
      final reviewedWrong = gradeOf(
        [text()],
        [
          ['x'],
        ],
        reviews: {SurveyScorer.reviewKey(surveyId, 0): false},
      );
      final notReviewed = gradeOf(
        [text()],
        [
          ['x'],
        ],
      );

      expect(reviewedWrong.gradedCount, 1);
      expect(reviewedWrong.percentage, 0);
      expect(notReviewed.gradedCount, 0);
      expect(notReviewed.hasPendingReview, isTrue);
    });

    // Re-grading from scratch is what makes an admin toggling a verdict
    // back and forth converge instead of inflating the stored score.
    test('toggling a verdict is idempotent', () {
      final questions = [text()];
      final answers = [
        ['x'],
      ];
      final key = SurveyScorer.reviewKey(surveyId, 0);

      final onceCorrect = gradeOf(questions, answers, reviews: {key: true});
      final twiceCorrect = gradeOf(questions, answers, reviews: {key: true});
      final thenWrong = gradeOf(questions, answers, reviews: {key: false});

      expect(onceCorrect.percentage, 100);
      expect(twiceCorrect.percentage, 100, reason: 'must not double-count');
      expect(
        thenWrong.percentage,
        0,
        reason: 'must subtract, not stick at 100',
      );
    });
  });

  group('whole submissions', () {
    test('percentage and correctCount always agree on a perfect paper', () {
      final grade = gradeOf(
        [
          single('a'),
          multiple(['a', 'b']),
          text(),
        ],
        [
          ['a'],
          ['a', 'b'],
          ['essay'],
        ],
        reviews: {SurveyScorer.reviewKey(surveyId, 2): true},
      );
      expect(grade.percentage, 100);
      expect(grade.correctCount, 3);
      expect(grade.gradedCount, 3);
    });

    test(
      'a survey with no questions scores zero rather than dividing by zero',
      () {
        final grade = gradeOf([], []);
        expect(grade.percentage, 0);
        expect(grade.gradedCount, 0);
      },
    );

    test('an unrecognised question type is excluded, not scored against', () {
      final grade = gradeOf(
        [
          {'type': 'Ranking', 'question': 'q'},
          single('a'),
        ],
        [
          ['whatever'],
          ['a'],
        ],
      );
      expect(grade.gradedCount, 1);
      expect(grade.percentage, 100);
    });

    test('grades are reported per question in order', () {
      final grade = gradeOf(
        [single('a'), single('b')],
        [
          ['a'],
          ['z'],
        ],
      );
      expect(grade.questions.map((q) => q.index), [0, 1]);
      expect(grade.questions.map((q) => q.isCorrect), [true, false]);
    });
  });

  group('key construction', () {
    test('answer and review keys match the stored Firestore format', () {
      expect(SurveyScorer.answerKey(3), 'Q3');
      expect(SurveyScorer.reviewKey('ABC123', 3), 'ABC123-Q3');
    });
  });
}
