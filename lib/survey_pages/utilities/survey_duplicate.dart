library;

import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';

/// Rebuilds the editable question list for a copy of a published survey.
///
/// A published survey is stored in two halves: the questions every member may
/// read, and the grading key only staff may read. The editor works on the
/// whole, so duplicating has to put them back together.
///
/// Everything is copied rather than shared. The source survey is still held in
/// the provider's list, and handing its option lists straight to the editor
/// would mean typing into the copy silently rewrote the original on screen.
///
/// A missing or short key list simply yields questions with nothing marked,
/// which is what a plain survey looks like and what an unreadable key should
/// degrade to — a copy the author must finish, never a copy with the wrong
/// answers marked right.
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
        // The editor holds a single index or nothing. Two marked answers on a
        // single-choice question means the key disagrees with the question, and
        // guessing which one to keep would publish a wrong key silently.
        if (valid.length == 1) copy['correctAnswer'] = valid.first;
      } else if (valid.isNotEmpty) {
        copy['correctAnswers'] = valid;
      }
    }

    rebuilt.add(copy);
  }

  return rebuilt;
}

/// A survey ready to be edited as a new one, carrying nothing that identifies
/// the original: no id, no author, no creation time, no participants.
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
    // Never the source deadline. Copying a survey that closed last month must
    // not produce one that is already shut, and the server rejects a deadline
    // in the past anyway.
    deadline: deadline,
    participants: const [],
    timeLimitPerQuestion: source.timeLimitPerQuestion,
    surveyType: source.surveyType,
    // Assigned by the server from the author's own membership.
    companyId: '',
  );
}
