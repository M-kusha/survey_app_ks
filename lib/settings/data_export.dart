library;

import 'dart:convert';

/// One survey or test the person took part in.
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

  /// Question text to the answer given, so the file makes sense on its own.
  final Map<String, Object?> answers;

  final double? score;
  final int? correctCount;
  final int? gradedCount;
}

/// One meeting, and which times the person said they could attend.
class ExportedVote {
  const ExportedVote({
    required this.appointmentId,
    required this.title,
    required this.statusBySlot,
  });

  final String appointmentId;
  final String title;

  /// A human-readable time to the answer given for it.
  final Map<String, String> statusBySlot;
}

class ExportedNote {
  const ExportedNote({required this.title, required this.body, this.updatedAt});

  final String title;
  final String body;
  final DateTime? updatedAt;
}

/// Everything EchoMeet holds about one person, as a portable document.
///
/// JSON rather than PDF: portability under GDPR means a machine-readable form
/// somebody can actually load somewhere else, and results already have a PDF
/// export for the readable case.
///
/// The shape is deliberately flat and self-describing. A file full of document
/// ids and option indexes would be a copy of the database, not a copy of the
/// person's data, so questions carry their text and votes carry their times.
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
      // Named rather than left to be noticed. A person reading a short export
      // cannot tell "you have no notes" from "notes could not be read", and
      // that difference matters when the file is the answer to a request.
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

  // Indented because a person opens this file and reads it.
  return const JsonEncoder.withIndent('  ').convert(document);
}

/// A file name that is safe on every platform and says what it holds.
String dataExportFileName(DateTime generatedAt) {
  final date = generatedAt.toUtc().toIso8601String().split('T').first;
  return 'echomeet-my-data-$date.json';
}
