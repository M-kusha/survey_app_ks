import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const questions = <Map<String, dynamic>>[
    {
      'type': 'Single',
      'question': 'Pick one',
      'options': ['A', 'B'],
    },
    {'type': 'Text', 'question': 'Explain'},
  ];

  SurveyGrade result({
    required String? status,
    int? gradedCount = 0,
    double score = 0,
    int correct = 0,
  }) => SurveyScorer.authoritativeGrade(
    surveyId: 'survey-1',
    questions: questions,
    answers: const {
      'Q0': [1],
      'Q1': ['Because'],
    },
    score: score,
    correctCount: correct,
    gradedCount: gradedCount,
    gradingStatus: status,
    textReviews: const {},
  );

  test('processing and corrupt states never look like final zero scores', () {
    for (final status in ['processing', 'error', 'unexpected']) {
      final grade = result(status: status);
      expect(grade.resultIsFinal, isFalse);
      expect(grade.scoreAvailable, isFalse);
      expect(grade.passed, isFalse);
      expect(grade.hasPendingReview, isFalse);
    }

    expect(result(status: 'processing').isProcessing, isTrue);
    expect(result(status: 'processing').hasGradingError, isFalse);
    expect(result(status: 'error').isProcessing, isFalse);
    expect(result(status: 'error').hasGradingError, isTrue);
    expect(result(status: 'unexpected').hasGradingError, isTrue);
  });

  test('trusted pending and final states preserve authoritative totals', () {
    final pending = result(
      status: 'pending_review',
      gradedCount: 1,
      score: 100,
      correct: 1,
    );
    expect(pending.hasPendingReview, isTrue);
    expect(pending.isProcessing, isFalse);
    expect(pending.hasGradingError, isFalse);
    expect(pending.scoreAvailable, isTrue);
    expect(pending.passed, isFalse);

    final finalGrade = result(
      status: 'final',
      gradedCount: 2,
      score: 50,
      correct: 1,
    );
    expect(finalGrade.resultIsFinal, isTrue);
    expect(finalGrade.scoreAvailable, isTrue);
    expect(finalGrade.passed, isTrue);
  });

  test('legacy documents infer pending text without deriving correctness', () {
    final grade = result(status: null, gradedCount: null, score: 75);
    expect(grade.hasPendingReview, isTrue);
    expect(grade.gradedCount, 1);
    expect(grade.percentage, 75);
  });
}
