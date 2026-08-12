import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> wireSurvey({String id = 'survey', bool deleting = false}) {
  final wire = <String, dynamic>{
    'surveyName': 'Quarterly pulse',
    'surveyDescription': 'A short check-in',
    'timeCreated': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
    'questions': <Map<String, dynamic>>[
      {'type': 'Text', 'question': 'How are things?'},
    ],
    'id': id,
    'participants': <Map<String, dynamic>>[],
    'deadline': Timestamp.fromDate(DateTime.utc(2026, 8, 20)),
    'timeLimitPerQuestion': 0,
    'surveyType': 0,
    'companyId': 'company',
    'createdBy': 'owner',
    'responsesRevision': 0,
  };
  if (deleting) {
    wire['deletionStartedAt'] = Timestamp.fromDate(DateTime.utc(2026, 8, 13));
  }
  return wire;
}

void main() {
  test('a survey leaves the list as soon as its deletion barrier appears', () {
    final rows = readSurveySnapshot([
      wireSurvey(id: 'stays'),
      wireSurvey(id: 'going', deleting: true),
    ]);

    expect(rows.map((row) => row.id), ['stays']);
  });

  test('one malformed survey cannot retain or stall the complete list', () {
    final malformed = wireSurvey(id: 'malformed')
      ..['timeCreated'] = 'not-a-timestamp';
    final failures = <Object>[];

    final rows = readSurveySnapshot([
      wireSurvey(id: 'first'),
      malformed,
      wireSurvey(id: 'third'),
    ], onUnreadable: failures.add);

    expect(rows.map((row) => row.id), ['first', 'third']);
    expect(failures.single, isA<TypeError>());
  });

  test('a malformed deletion marker is reported and omitted', () {
    final failures = <Object>[];
    final rows = readSurveySnapshot([
      wireSurvey()..['deletionStartedAt'] = 13,
    ], onUnreadable: failures.add);

    expect(rows, isEmpty);
    expect(failures.single, isA<FormatException>());
  });
}
