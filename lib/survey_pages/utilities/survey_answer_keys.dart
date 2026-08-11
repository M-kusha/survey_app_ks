class SurveyDocumentQuestions {
  const SurveyDocumentQuestions({
    required this.publicQuestions,
    required this.privateAnswerKeys,
  });

  final List<Map<String, dynamic>> publicQuestions;
  final List<Map<String, dynamic>> privateAnswerKeys;
}

/// Separates publishable question content from the grading material used by
/// the trusted scoring function.
///
/// The returned maps are copies. The editor can therefore keep its answer
/// selections in memory while the survey document sent to Firestore contains
/// no `correctAnswer` or `correctAnswers` fields.
SurveyDocumentQuestions splitSurveyQuestions(
  List<Map<String, dynamic>> questions,
) {
  final publicQuestions = <Map<String, dynamic>>[];
  final privateAnswerKeys = <Map<String, dynamic>>[];

  for (final source in questions) {
    final published = Map<String, dynamic>.from(source)
      ..remove('correctAnswer')
      ..remove('correctAnswers');
    final type = source['type'];

    publicQuestions.add(published);
    privateAnswerKeys.add({
      'type': type,
      if (type == 'Single' && source['correctAnswer'] is int)
        'correctAnswer': source['correctAnswer'],
      if (type == 'Multiple' &&
          source['correctAnswers'] is List<dynamic> &&
          (source['correctAnswers'] as List<dynamic>).isNotEmpty)
        'correctAnswers': List<int>.from(
          (source['correctAnswers'] as List<dynamic>).whereType<int>(),
        ),
    });
  }

  return SurveyDocumentQuestions(
    publicQuestions: publicQuestions,
    privateAnswerKeys: privateAnswerKeys,
  );
}

/// The correct option indexes per question, read back out of a stored answer
/// key document.
///
/// Grading itself belongs to the trusted function; this is only so the review
/// screen can show a marker which option was right. Anything unrecognised
/// yields an empty set for that question, which renders as unmarked rather
/// than as a wrong answer.
List<Set<int>> readAnswerKeyIndexes(Map<String, dynamic>? answerKey) {
  final questionKeys = answerKey?['questionKeys'];
  if (questionKeys is! List) return const [];

  return [
    // Deliberately `Map` and not `Map<String, dynamic>`: maps nested inside an
    // array come back from the web SDK without that type argument, and a
    // stricter check silently skips every question.
    for (final entry in questionKeys)
      entry is Map ? _correctIndexesOf(entry) : const <int>{},
  ];
}

/// The correct option indexes declared on one answer key entry.
Set<int> _correctIndexesOf(Map<dynamic, dynamic> source) =>
    switch (source['type']) {
      'Single' when source['correctAnswer'] is int => {
        source['correctAnswer'] as int,
      },
      'Multiple' when source['correctAnswers'] is List =>
        (source['correctAnswers'] as List).whereType<int>().toSet(),
      _ => const <int>{},
    };
