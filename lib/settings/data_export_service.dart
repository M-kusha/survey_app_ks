import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/settings/data_export.dart';
import 'package:intl/intl.dart';

class DataExportService {
  DataExportService({FirebaseFirestore? firestore, String? locale})
    : _firestore = firestore,
      _locale = locale ?? 'en';

  final FirebaseFirestore? _firestore;
  final String _locale;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<String> buildExport({
    required String userId,
    required String companyId,
    DateTime? now,
  }) async {
    final generatedAt = now ?? DateTime.now();
    final omissions = <String>[];

    final profile = await _guard(
      () => _profile(userId),
      const <String, Object?>{},
      omissions,
      'profile',
    );
    final notes = await _guard(
      () => _notes(userId),
      const <ExportedNote>[],
      omissions,
      'notes',
    );
    final participation = await _guard(
      () => _participation(userId, companyId),
      const <ExportedParticipation>[],
      omissions,
      'surveysAndTests',
    );
    final votes = await _guard(
      () => _votes(userId, companyId),
      const <ExportedVote>[],
      omissions,
      'meetingVotes',
    );

    return buildDataExport(
      generatedAt: generatedAt,
      userId: userId,
      profile: profile,
      notes: notes,
      participation: participation,
      votes: votes,
      omissions: omissions,
    );
  }

  Future<T> _guard<T>(
    Future<T> Function() read,
    T fallback,
    List<String> omissions,
    String section,
  ) async {
    try {
      return await read();
    } on Object {
      omissions.add(section);
      return fallback;
    }
  }

  Future<Map<String, Object?>> _profile(String userId) async {
    final snapshot = await _db.collection('users').doc(userId).get();
    final data = snapshot.data() ?? const <String, dynamic>{};

    return {
      for (final entry in data.entries)
        if (entry.key != 'fcmTokens') entry.key: _plain(entry.value),
    };
  }

  Future<List<ExportedNote>> _notes(String userId) async {
    final rows = await _db
        .collection('notes')
        .doc(userId)
        .collection('userNotes')
        .get();

    final notes = <ExportedNote>[];
    for (final row in rows.docs) {
      final body = await _db
          .collection('users')
          .doc(userId)
          .collection('notes')
          .doc(row.id)
          .get();
      final timestamp = row.data()['timestamp'];

      notes.add(
        ExportedNote(
          title: '${row.data()['title'] ?? ''}',

          body: '${body.data()?['content'] ?? row.data()['preview'] ?? ''}',
          updatedAt: timestamp is Timestamp ? timestamp.toDate() : null,
        ),
      );
    }
    return notes;
  }

  Future<List<ExportedParticipation>> _participation(
    String userId,
    String companyId,
  ) async {
    if (companyId.isEmpty) return const [];

    final surveys = await _db
        .collection('surveys')
        .where('companyId', isEqualTo: companyId)
        .get();

    final participation = <ExportedParticipation>[];
    for (final survey in surveys.docs) {
      final mine = await survey.reference
          .collection('participants')
          .doc(userId)
          .get();
      if (!mine.exists) continue;

      final data = mine.data() ?? const <String, dynamic>{};
      final questions = (survey.data()['questions'] as List?) ?? const [];
      final answers = <String, Object?>{};
      final raw = data['surveyAnswers'];
      if (raw is Map) {
        for (final entry in raw.entries) {
          answers[_questionText(questions, '${entry.key}')] = _plain(
            entry.value,
          );
        }
      }

      final isTest = survey.data()['surveyType'] == 1;
      participation.add(
        ExportedParticipation(
          surveyId: survey.id,
          surveyName: '${survey.data()['surveyName'] ?? ''}',
          isTest: isTest,
          answers: answers,
          score: isTest ? _number(data['score']) : null,
          correctCount: isTest ? _integer(data['totalCorrectAnswers']) : null,
          gradedCount: isTest ? _integer(data['gradedQuestionCount']) : null,
        ),
      );
    }
    return participation;
  }

  Future<List<ExportedVote>> _votes(String userId, String companyId) async {
    if (companyId.isEmpty) return const [];

    final appointments = await _db
        .collection('appointments')
        .where('companyId', isEqualTo: companyId)
        .where('schemaVersion', isEqualTo: Appointment.schemaVersion)
        .get();

    final votes = <ExportedVote>[];
    for (final appointment in appointments.docs) {
      final mine = await appointment.reference
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();
      if (mine.docs.isEmpty) continue;

      final slots = {
        for (final slot in (appointment.data()['slots'] as List?) ?? const [])
          if (slot is Map) '${slot['slotId']}': slot,
      };

      votes.add(
        ExportedVote(
          appointmentId: appointment.id,
          title: '${appointment.data()['title'] ?? ''}',
          statusBySlot: {
            for (final vote in mine.docs)
              _slotLabel(
                slots['${vote.data()['slotId']}'],
                '${appointment.data()['zoneId']}',
              ): '${vote.data()['status']}',
          },
        ),
      );
    }
    return votes;
  }

  String _questionText(List<dynamic> questions, String key) {
    final index = int.tryParse(key);
    if (index != null && index >= 0 && index < questions.length) {
      final question = questions[index];
      if (question is Map && question['question'] is String) {
        return question['question'] as String;
      }
    }
    return key;
  }

  String _slotLabel(Object? slot, String zoneId) {
    if (slot is! Map) return 'unknown';
    final start = slot['startAt'];
    if (start is! Timestamp) return '${slot['slotId']}';
    return DateFormat.yMMMd(
      _locale,
    ).add_jm().format(appointmentTimeInZone(start.toDate(), zoneId));
  }

  Object? _plain(Object? value) => switch (value) {
    Timestamp() => value.toDate().toUtc().toIso8601String(),
    DocumentReference() => value.path,
    List() => [for (final item in value) _plain(item)],
    Map() => {
      for (final entry in value.entries) '${entry.key}': _plain(entry.value),
    },
    _ => value,
  };

  double? _number(Object? value) => switch (value) {
    num() => value.toDouble(),
    _ => null,
  };

  int? _integer(Object? value) => switch (value) {
    int() => value,
    _ => null,
  };
}
