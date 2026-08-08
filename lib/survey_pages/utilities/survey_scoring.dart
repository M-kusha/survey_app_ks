/// Scoring rules for surveys and tests.
///
/// This library is deliberately pure: no Flutter, no Firestore, no widget
/// state. A grade is always *derived* from the survey definition plus the
/// participant's answers, never accumulated as the user or an admin clicks
/// around. That property is what keeps the participant's score and their
/// correct-answer count from drifting apart, and it makes every rule below
/// directly unit-testable.
library;

/// The question kinds the app can author. The stored value is a display string
/// (`'Single'`, `'Multiple'`, `'Text'`), so parsing is tolerant of anything
/// unexpected rather than throwing on data written by an older build.
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

/// The outcome for a single question.
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

  /// Whether this question counted toward the score at all.
  ///
  /// Free-text answers are only graded once a reviewer has judged them, so an
  /// unreviewed text question is excluded from both the numerator and the
  /// denominator. Including it would make 100% unreachable while review is
  /// still outstanding.
  final bool isGraded;

  /// Whether the answer earned full marks. Partial credit is *not* correct.
  final bool isCorrect;

  /// Fraction of the question's marks earned, in `0.0..1.0`.
  final double credit;

  /// A question that still needs a human decision before it can be scored.
  bool get awaitsReview => type == QuestionType.text && !isGraded;
}

/// The outcome for a whole submission.
class SurveyGrade {
  const SurveyGrade({
    required this.questions,
    required this.gradedCount,
    required this.correctCount,
    required this.percentage,
  });

  final List<QuestionGrade> questions;

  /// How many questions actually counted toward [percentage].
  final int gradedCount;

  /// How many graded questions earned full marks.
  final int correctCount;

  /// Score in `0.0..100.0`, averaged over [gradedCount] questions only.
  final double percentage;

  /// True while any free-text answer is still awaiting review, which means
  /// [percentage] is provisional.
  bool get hasPendingReview => questions.any((q) => q.awaitsReview);
}

/// Grades submissions against a survey definition.
abstract final class SurveyScorer {
  /// Key used for a question's answers inside `Participant.surveyAnswers`.
  static String answerKey(int questionIndex) => 'Q$questionIndex';

  /// Key used for a reviewer's verdict inside `Participant.textAnswersReviewed`.
  ///
  /// Scoped by survey id so one participant's verdicts cannot collide across
  /// the surveys they have taken.
  static String reviewKey(String surveyId, int questionIndex) =>
      '$surveyId-${answerKey(questionIndex)}';

  /// Grades [answers] against [questions].
  ///
  /// [textReviews] carries reviewer verdicts keyed by [reviewKey]; a missing
  /// entry means "not yet reviewed", which is deliberately distinct from a
  /// `false` entry meaning "reviewed and judged wrong".
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
      // An unrecognised type cannot be graded fairly, so it is excluded rather
      // than silently scored as zero against the participant.
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

  /// Partial credit, with wrong selections cancelling out right ones.
  ///
  /// Without that subtraction, ticking every option would intersect fully with
  /// the correct set and score 100% on every multiple-choice question.
  static QuestionGrade _gradeMultiple(
    int index,
    Map<String, dynamic> question,
    List<dynamic> answer,
  ) {
    final expected = Set<dynamic>.from(
      (question['correctAnswers'] as List<dynamic>?) ?? const [],
    );
    final chosen = Set<dynamic>.from(answer);

    // A question with no correct answers recorded is unanswerable; excluding it
    // avoids dividing by zero and avoids punishing the participant for an
    // authoring mistake.
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
      // Full marks require the exact set: no misses and no extras.
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
