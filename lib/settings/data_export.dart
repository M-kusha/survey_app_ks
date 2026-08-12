library;

import 'dart:convert';

class ExportedParticipation {
  const ExportedParticipation({
    required this.surveyId,
    required this.surveyName,
    required this.isTest,
    required this.answers,
    this.score,
    this.correctCount,
    this.gradedCount,
  });

  final String surveyId;
  final String surveyName;
  final bool isTest;

  final Map<String, Object?> answers;

  final double? score;
  final int? correctCount;
  final int? gradedCount;
}

class ExportedVote {
  const ExportedVote({
    required this.appointmentId,
    required this.title,
    required this.statusBySlot,
  });

  final String appointmentId;
  final String title;

  final Map<String, String> statusBySlot;
}

class ExportedNote {
  const ExportedNote({required this.title, required this.body, this.updatedAt});

  final String title;
  final String body;
  final DateTime? updatedAt;
}

String buildDataExport({
  required DateTime generatedAt,
  required String userId,
  required Map<String, Object?> profile,
  required List<ExportedNote> notes,
  required List<ExportedParticipation> participation,
  required List<ExportedVote> votes,
  List<String> omissions = const [],
}) {
  final document = <String, Object?>{
    'export': {
      'application': 'EchoMeet',
      'formatVersion': 1,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'userId': userId,

      if (omissions.isNotEmpty) 'couldNotBeIncluded': omissions,
    },
    'profile': profile,
    'notes': [
      for (final note in notes)
        {
          'title': note.title,
          'body': note.body,
          if (note.updatedAt case final updatedAt?)
            'updatedAt': updatedAt.toUtc().toIso8601String(),
        },
    ],
    'surveysAndTests': [
      for (final entry in participation)
        {
          'surveyId': entry.surveyId,
          'name': entry.surveyName,
          'kind': entry.isTest ? 'test' : 'survey',
          'answers': entry.answers,
          if (entry.isTest) ...{
            'score': entry.score,
            'correctAnswers': entry.correctCount,
            'gradedQuestions': entry.gradedCount,
          },
        },
    ],
    'meetingVotes': [
      for (final vote in votes)
        {
          'appointmentId': vote.appointmentId,
          'title': vote.title,
          'answers': vote.statusBySlot,
        },
    ],
  };

  return const JsonEncoder.withIndent('  ').convert(document);
}

String dataExportFileName(DateTime generatedAt) {
  final date = generatedAt.toUtc().toIso8601String().split('T').first;
  return 'echomeet-my-data-$date.json';
}
