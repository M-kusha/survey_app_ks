import 'dart:convert';

import 'package:echomeet/settings/data_export.dart';
import 'package:flutter_test/flutter_test.dart';

final _at = DateTime.utc(2026, 8, 12, 9, 30);

Map<String, dynamic> _export({
  Map<String, Object?> profile = const {'fullName': 'Bea'},
  List<ExportedNote> notes = const [],
  List<ExportedParticipation> participation = const [],
  List<ExportedVote> votes = const [],
  List<String> omissions = const [],
}) {
  final json = buildDataExport(
    generatedAt: _at,
    userId: 'uid-1',
    profile: profile,
    notes: notes,
    participation: participation,
    votes: votes,
    omissions: omissions,
  );
  return jsonDecode(json) as Map<String, dynamic>;
}

void main() {
  test('the document says what it is and when it was made', () {
    final export = _export();
    final header = export['export'] as Map<String, dynamic>;

    expect(header['application'], 'EchoMeet');
    expect(header['formatVersion'], 1);
    expect(header['userId'], 'uid-1');
    expect(header['generatedAt'], '2026-08-12T09:30:00.000Z');
  });

  test('an empty account still produces every section', () {
    final export = _export();

    // A reader must be able to tell "nothing here" from "this export is
    // missing a section", so the keys are always present.
    expect(
      export.keys,
      containsAll(['profile', 'notes', 'surveysAndTests', 'meetingVotes']),
    );
    expect(export['notes'], isEmpty);
    expect(export['surveysAndTests'], isEmpty);
    expect(export['meetingVotes'], isEmpty);
  });

  test('nothing is claimed to be missing when nothing is', () {
    expect(
      (_export()['export'] as Map<String, dynamic>).containsKey(
        'couldNotBeIncluded',
      ),
      isFalse,
    );
  });

  test('a section that failed to load is named, not silently dropped', () {
    // The difference between "you have no notes" and "your notes could not be
    // read" matters when the file is the answer to a data request.
    final export = _export(omissions: const ['notes']);

    expect((export['export'] as Map<String, dynamic>)['couldNotBeIncluded'], [
      'notes',
    ]);
  });

  test('answers carry the question text, not an id', () {
    final export = _export(
      participation: [
        const ExportedParticipation(
          surveyId: 's1',
          surveyName: 'Onboarding',
          isTest: false,
          answers: {'How did it go?': 'Well'},
        ),
      ],
    );

    final entry = (export['surveysAndTests'] as List).single;
    expect(entry['name'], 'Onboarding');
    expect(entry['kind'], 'survey');
    expect(entry['answers'], {'How did it go?': 'Well'});
  });

  test('a survey carries no score fields, a test does', () {
    final survey =
        (_export(
                      participation: [
                        const ExportedParticipation(
                          surveyId: 's1',
                          surveyName: 'Mood',
                          isTest: false,
                          answers: {},
                        ),
                      ],
                    )['surveysAndTests']
                    as List)
                .single
            as Map<String, dynamic>;

    expect(survey.containsKey('score'), isFalse);

    final test =
        (_export(
                      participation: [
                        const ExportedParticipation(
                          surveyId: 't1',
                          surveyName: 'Security',
                          isTest: true,
                          answers: {},
                          score: 80,
                          correctCount: 8,
                          gradedCount: 10,
                        ),
                      ],
                    )['surveysAndTests']
                    as List)
                .single
            as Map<String, dynamic>;

    expect(test['kind'], 'test');
    expect(test['score'], 80);
    expect(test['correctAnswers'], 8);
    expect(test['gradedQuestions'], 10);
  });

  test('votes carry readable times rather than slot ids', () {
    final export = _export(
      votes: [
        const ExportedVote(
          appointmentId: 'a1',
          title: 'Planning',
          statusBySlot: {'Aug 18, 2026 9:00 AM': 'joined'},
        ),
      ],
    );

    final vote = (export['meetingVotes'] as List).single;
    expect(vote['title'], 'Planning');
    expect(vote['answers'], {'Aug 18, 2026 9:00 AM': 'joined'});
  });

  test('a note without a timestamp omits the field rather than nulling it', () {
    final export = _export(
      notes: [
        const ExportedNote(title: 'Idea', body: 'Something'),
        ExportedNote(
          title: 'Dated',
          body: 'Other',
          updatedAt: DateTime.utc(2026, 3, 1),
        ),
      ],
    );

    final notes = (export['notes'] as List).cast<Map<String, dynamic>>();
    expect(notes.first.containsKey('updatedAt'), isFalse);
    expect(notes.last['updatedAt'], '2026-03-01T00:00:00.000Z');
  });

  test('the output is indented, because a person opens it', () {
    final json = buildDataExport(
      generatedAt: _at,
      userId: 'uid-1',
      profile: const {'fullName': 'Bea'},
      notes: const [],
      participation: const [],
      votes: const [],
    );

    expect(json, contains('\n  "profile"'));
  });

  test('the file name is safe everywhere and dated', () {
    expect(dataExportFileName(_at), 'echomeet-my-data-2026-08-12.json');
    expect(dataExportFileName(_at), isNot(contains(':')));
  });
}
