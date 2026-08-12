List<Set<int>> readAnswerKeyIndexes(Map<String, dynamic>? answerKey) {
  final questionKeys = answerKey?['questionKeys'];
  if (questionKeys is! List) return const [];

  return [
    for (final entry in questionKeys)
      entry is Map ? _correctIndexesOf(entry) : const <int>{},
  ];
}

Set<int> _correctIndexesOf(Map<dynamic, dynamic> source) =>
    switch (source['type']) {
      'Single' when source['correctAnswer'] is int => {
        source['correctAnswer'] as int,
      },
      'Multiple' when source['correctAnswers'] is List =>
        (source['correctAnswers'] as List).whereType<int>().toSet(),
      _ => const <int>{},
    };
