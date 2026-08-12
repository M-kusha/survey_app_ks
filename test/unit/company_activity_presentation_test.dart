import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/membership/company_activity_service.dart';
import 'package:echomeet/settings/administrative_activity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_translations.dart';

CompanyActivity contentActivity(
  String action, {
  String type = 'appointment',
  String actorUid = 'actor_1',
  Map<String, dynamic> after = const {},
}) => CompanyActivity(
  id: 'activity_1',
  companyId: 'company_1',
  action: action,
  actorUid: actorUid,
  occurredAt: DateTime.utc(2026, 8, 12),
  before: const {},
  after: after,
  entity: CompanyActivityEntity(
    type: type,
    id: 'content_1',
    title: 'Quarterly planning',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('survey and test creation are explicit in EN, DE and SQ', () async {
    const expected = {
      'en': (
        survey: 'Ada created the survey “Quarterly planning”',
        test:
            'Ada created the test “Quarterly planning” and marked its correct answers',
      ),
      'de': (
        survey: 'Ada hat die Umfrage „Quarterly planning“ erstellt',
        test:
            'Ada hat den Test „Quarterly planning“ erstellt und die richtigen Antworten festgelegt',
      ),
      'sq': (
        survey: 'Ada krijoi anketën “Quarterly planning”',
        test:
            'Ada krijoi testin “Quarterly planning” dhe shënoi përgjigjet e sakta',
      ),
    };

    for (final locale in expected.keys) {
      await loadAppTranslations(locale: locale);
      final copy = expected[locale]!;
      expect(
        companyActivityDescription(
          contentActivity('survey.created', type: 'survey'),
          const {'actor_1': 'Ada'},
        ),
        copy.survey,
      );
      expect(
        companyActivityDescription(
          contentActivity('survey.created', type: 'test'),
          const {'actor_1': 'Ada'},
        ),
        copy.test,
      );
    }
  });

  test('every new content action renders names and subjects', () async {
    final confirmedAt = Timestamp.fromDate(DateTime(2026, 8, 14, 10, 30));
    final entries = [
      contentActivity('survey.created', type: 'survey'),
      contentActivity('survey.deleted', type: 'test'),
      contentActivity('appointment.created'),
      contentActivity('appointment.updated'),
      contentActivity('appointment.deleted'),
      contentActivity(
        'appointment.slot_confirmed',
        after: {'confirmedStartAt': confirmedAt},
      ),
    ];

    for (final locale in const ['en', 'de', 'sq']) {
      await loadAppTranslations(locale: locale);
      for (final entry in entries) {
        final description = companyActivityDescription(entry, const {
          'actor_1': 'Ada',
        });
        expect(description, contains('Ada'), reason: '$locale ${entry.action}');
        expect(
          description,
          contains('Quarterly planning'),
          reason: '$locale ${entry.action}',
        );
        expect(
          description,
          isNot(contains('{')),
          reason: '$locale ${entry.action}',
        );
        expect(
          companyActivityIcon(entry),
          isNot(Icons.history_rounded),
          reason: entry.action,
        );
      }
    }
  });

  test('a missing directory name never exposes its UID', () async {
    const expectedFallback = {
      'en': 'A former member',
      'de': 'Ein ehemaliges Mitglied',
      'sq': 'Një ish-anëtar',
    };
    for (final locale in expectedFallback.keys) {
      await loadAppTranslations(locale: locale);
      final description = companyActivityDescription(
        contentActivity('appointment.deleted', actorUid: 'private_uid_123'),
        const {},
      );
      expect(description, contains(expectedFallback[locale]!));
      expect(description, isNot(contains('private_uid_123')));
    }
  });

  test(
    'unsafe directory controls are normalized at presentation time',
    () async {
      await loadAppTranslations();
      final description = companyActivityDescription(
        contentActivity('appointment.created'),
        const {'actor_1': 'Ada\n\u202eecilA'},
      );

      expect(description, startsWith('Ada ecilA created'));
      expect(description, isNot(contains('\n')));
      expect(description, isNot(contains('\u202e')));
    },
  );
}
