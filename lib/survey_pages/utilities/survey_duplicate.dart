library;

import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';

List<Map<String, dynamic>> duplicateSurveyQuestions({
  required List<Map<String, dynamic>> questions,
  required List<Set<int>> correctIndexes,
}) {
  final rebuilt = <Map<String, dynamic>>[];

  for (final (index, question) in questions.indexed) {
    final type = question['type'];
    final text = question['question'];
    if (type is! String || text is! String) continue;

    final copy = <String, dynamic>{'type': type, 'question': text};

    if (type == 'Single' || type == 'Multiple') {
      copy['options'] = [
        for (final option in (question['options'] as List?) ?? const [])
          '$option',
      ];

      final correct = index < correctIndexes.length
          ? correctIndexes[index]
          : const <int>{};
      final optionCount = (copy['options'] as List).length;
      final valid = correct.where((at) => at >= 0 && at < optionCount).toList()
        ..sort();

      if (type == 'Single') {
        if (valid.length == 1) copy['correctAnswer'] = valid.first;
      } else if (valid.isNotEmpty) {
        copy['correctAnswers'] = valid;
      }
    }

    rebuilt.add(copy);
  }

  return rebuilt;
}

Survey duplicateSurveyTemplate({
  required Survey source,
  required List<Set<int>> correctIndexes,
  required String name,
  required String newId,
  required DateTime deadline,
}) {
  return Survey(
    surveyName: name,
    surveyDescription: source.surveyDescription,
    timeCreated: DateTime.now(),
    questions: duplicateSurveyQuestions(
      questions: source.questions,
      correctIndexes: correctIndexes,
    ),
    id: newId,

    deadline: deadline,
    participants: const [],
    timeLimitPerQuestion: source.timeLimitPerQuestion,
    surveyType: source.surveyType,
    companyId: '',
  );
}
