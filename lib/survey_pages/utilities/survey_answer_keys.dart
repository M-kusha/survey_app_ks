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
