library;

enum QuestionType {
  single,
  multiple,
  text,
  unknown;

  static QuestionType parse(Object? raw) => switch (raw) {
    'Single' => QuestionType.single,
    'Multiple' => QuestionType.multiple,
    'Text' => QuestionType.text,
    _ => QuestionType.unknown,
  };
}

class QuestionGrade {
  const QuestionGrade({
    required this.index,
    required this.type,
    required this.isGraded,
    required this.isCorrect,
    required this.credit,
  });

  final int index;
  final QuestionType type;

  final bool isGraded;

  final bool isCorrect;

  final double credit;

  bool get awaitsReview => type == QuestionType.text && !isGraded;
}

const double kPassingPercentage = 50;

enum SurveyGradingStatus { processing, pendingReview, finalResult, error }

class SurveyGrade {
  const SurveyGrade({
    required this.questions,
    required this.gradedCount,
    required this.correctCount,
    required this.percentage,
    this.authoritativeStatus,
  });

  final List<QuestionGrade> questions;

  final int gradedCount;

  final int correctCount;

  final double percentage;

  final SurveyGradingStatus? authoritativeStatus;

  bool get isProcessing =>
      authoritativeStatus == SurveyGradingStatus.processing;

  bool get hasPendingReview => authoritativeStatus != null
      ? authoritativeStatus == SurveyGradingStatus.pendingReview
      : questions.any((q) => q.awaitsReview);

  bool get hasGradingError => authoritativeStatus == SurveyGradingStatus.error;

  bool get resultIsFinal => authoritativeStatus != null
      ? authoritativeStatus == SurveyGradingStatus.finalResult
      : !hasPendingReview;

  bool get scoreAvailable =>
      authoritativeStatus == null ||
      authoritativeStatus == SurveyGradingStatus.pendingReview ||
      authoritativeStatus == SurveyGradingStatus.finalResult;

  bool get passed => resultIsFinal && percentage >= kPassingPercentage;
}

abstract final class SurveyScorer {
  static String answerKey(int questionIndex) => 'Q$questionIndex';

  static String reviewKey(String surveyId, int questionIndex) =>
      '$surveyId-${answerKey(questionIndex)}';

  static SurveyGrade authoritativeGrade({
    required String surveyId,
    required List<Map<String, dynamic>> questions,
    required Map<String, List<dynamic>> answers,
    required double score,
    required int correctCount,
    required int? gradedCount,
    required String? gradingStatus,
    required Map<String, bool> textReviews,
  }) {
    final status = switch (gradingStatus) {
      'processing' => SurveyGradingStatus.processing,
      'pending_review' => SurveyGradingStatus.pendingReview,
      'final' => SurveyGradingStatus.finalResult,
      'error' => SurveyGradingStatus.error,
      null => _legacyStatus(
        surveyId: surveyId,
        questions: questions,
        answers: answers,
        textReviews: textReviews,
      ),
      _ => SurveyGradingStatus.error,
    };

    final safeScore = score.isFinite ? score.clamp(0.0, 100.0) : 0.0;
    final safeCorrect = correctCount < 0 ? 0 : correctCount;
    final safeGraded = gradedCount == null || gradedCount < 0
        ? _legacyGradedCount(
            surveyId: surveyId,
            questions: questions,
            answers: answers,
            textReviews: textReviews,
          )
        : gradedCount;

    return SurveyGrade(
      questions: const [],
      gradedCount: safeGraded,
      correctCount: safeCorrect.clamp(0, safeGraded),
      percentage: safeScore,
      authoritativeStatus: status,
    );
  }

  static SurveyGradingStatus _legacyStatus({
    required String surveyId,
    required List<Map<String, dynamic>> questions,
    required Map<String, List<dynamic>> answers,
    required Map<String, bool> textReviews,
  }) {
    for (var index = 0; index < questions.length; index++) {
      if (QuestionType.parse(questions[index]['type']) != QuestionType.text) {
        continue;
      }
      final answer = answers[answerKey(index)] ?? const [];
      if (answer.join().trim().isNotEmpty &&
          !textReviews.containsKey(reviewKey(surveyId, index))) {
        return SurveyGradingStatus.pendingReview;
      }
    }
    return SurveyGradingStatus.finalResult;
  }

  static int _legacyGradedCount({
    required String surveyId,
    required List<Map<String, dynamic>> questions,
    required Map<String, List<dynamic>> answers,
    required Map<String, bool> textReviews,
  }) {
    var count = 0;
    for (var index = 0; index < questions.length; index++) {
      final type = QuestionType.parse(questions[index]['type']);
      if (type == QuestionType.unknown) continue;
      if (type != QuestionType.text) {
        count += 1;
        continue;
      }

      final answer = answers[answerKey(index)] ?? const [];
      if (answer.join().trim().isEmpty ||
          textReviews.containsKey(reviewKey(surveyId, index))) {
        count += 1;
      }
    }
    return count;
  }

  static SurveyGrade grade({
    required String surveyId,
    required List<Map<String, dynamic>> questions,
    required Map<String, List<dynamic>> answers,
    Map<String, bool> textReviews = const {},
  }) {
    final grades = <QuestionGrade>[];

    for (var i = 0; i < questions.length; i++) {
      grades.add(
        _gradeQuestion(
          index: i,
          question: questions[i],
          answer: answers[answerKey(i)] ?? const [],
          review: textReviews[reviewKey(surveyId, i)],
        ),
      );
    }

    final graded = grades.where((g) => g.isGraded).toList(growable: false);
    final creditEarned = graded.fold<double>(0, (sum, g) => sum + g.credit);

    return SurveyGrade(
      questions: List.unmodifiable(grades),
      gradedCount: graded.length,
      correctCount: graded.where((g) => g.isCorrect).length,
      percentage: graded.isEmpty ? 0 : (creditEarned / graded.length) * 100,
    );
  }

  static QuestionGrade _gradeQuestion({
    required int index,
    required Map<String, dynamic> question,
    required List<dynamic> answer,
    required bool? review,
  }) {
    final type = QuestionType.parse(question['type']);

    return switch (type) {
      QuestionType.single => _gradeSingle(index, question, answer),
      QuestionType.multiple => _gradeMultiple(index, question, answer),
      QuestionType.text => _gradeText(index, review),

      QuestionType.unknown => QuestionGrade(
        index: index,
        type: type,
        isGraded: false,
        isCorrect: false,
        credit: 0,
      ),
    };
  }

  static QuestionGrade _gradeSingle(
    int index,
    Map<String, dynamic> question,
    List<dynamic> answer,
  ) {
    final isCorrect =
        answer.length == 1 && answer.first == question['correctAnswer'];
    return QuestionGrade(
      index: index,
      type: QuestionType.single,
      isGraded: true,
      isCorrect: isCorrect,
      credit: isCorrect ? 1 : 0,
    );
  }

  static QuestionGrade _gradeMultiple(
    int index,
    Map<String, dynamic> question,
    List<dynamic> answer,
  ) {
    final expected = Set<dynamic>.from(
      (question['correctAnswers'] as List<dynamic>?) ?? const [],
    );
    final chosen = Set<dynamic>.from(answer);

    if (expected.isEmpty) {
      return QuestionGrade(
        index: index,
        type: QuestionType.multiple,
        isGraded: false,
        isCorrect: false,
        credit: 0,
      );
    }

    final hits = chosen.intersection(expected).length;
    final wrong = chosen.difference(expected).length;
    final credit = ((hits - wrong) / expected.length).clamp(0.0, 1.0);

    return QuestionGrade(
      index: index,
      type: QuestionType.multiple,
      isGraded: true,

      isCorrect:
          chosen.length == expected.length && chosen.containsAll(expected),
      credit: credit,
    );
  }

  static QuestionGrade _gradeText(int index, bool? review) => QuestionGrade(
    index: index,
    type: QuestionType.text,
    isGraded: review != null,
    isCorrect: review ?? false,
    credit: (review ?? false) ? 1 : 0,
  );
}
