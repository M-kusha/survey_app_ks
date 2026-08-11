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
