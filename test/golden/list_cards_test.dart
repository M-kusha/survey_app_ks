import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/main_screen/appointment_list.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/survey_pages/main_sruvey/survey_list.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

/// Every state a list row can be in, side by side.
///
///     flutter test --update-goldens test/golden
///
/// These exist because the states are the part nobody looks at. Open rows get
/// exercised constantly; expired and already-answered ones are what a reviewer
/// sees on a stale account, and until now there was no way to check they read
/// as finished rather than as broken.
///
/// Dates are fixed relative to a frozen "now" so the deadline copy is stable —
/// a golden built from `DateTime.now()` would rewrite itself daily.
final _now = DateTime(2025, 3, 10, 9);

Survey _survey({
  required String name,
  required Duration closesIn,
  SurveyType type = SurveyType.survey,
  int questions = 8,
}) => Survey(
  surveyName: name,
  surveyDescription: '',
  timeCreated: _now.subtract(const Duration(days: 6)),
  questions: List.generate(questions, (_) => <String, dynamic>{}),
  id: 'id-$name',
  deadline: _now.add(closesIn),
  participants: [],
  surveyType: type,
  companyId: 'acme',
);

TimeSlot _slot(int day, int hour, {bool confirmed = false}) => TimeSlot(
  slotId: 'slot-$day-$hour',
  start: DateTime(2025, 3, day, hour),
  end: DateTime(2025, 3, day, hour + 1),
  isConfirmed: confirmed,
);

Appointment _appointment({
  required String title,
  required Duration closesIn,
  required List<TimeSlot> slots,
  int voters = 4,
}) {
  final confirmed = slots.where((slot) => slot.isConfirmed).firstOrNull;
  return Appointment(
    appointmentId: 'id-$title',
    title: title,
    description: '',
    zoneId: 'Europe/Berlin',
    availableTimeSlots: slots,
    expirationDate: _now.add(closesIn),
    creationDate: _now.subtract(const Duration(days: 4)),
    confirmedSlotId: confirmed?.slotId,
    participantUserIds: List.generate(voters, (i) => 'u$i'),
  );
}

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  tester.view.physicalSize = const Size(560, 1180);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(disableAnimations: true),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(Spacing.lg),
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _gap() => const SizedBox(height: Spacing.md);

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppFonts();
    await loadAppTranslations();
  });

  for (final (name, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    testWidgets('survey rows in every state — $name', (tester) async {
      await _pump(
        tester,
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel(label: 'Waiting on you', count: 3),
            SurveyListItem(
              survey: _survey(
                name: 'Onboarding feedback',
                closesIn: const Duration(days: 12),
              ),
              isAdmin: true,
              hasParticipated: false,
              now: _now,
            ),
            _gap(),
            SurveyListItem(
              survey: _survey(
                name: 'Security basics',
                closesIn: const Duration(hours: 6),
                type: SurveyType.test,
                questions: 20,
              ),
              isAdmin: false,
              hasParticipated: false,
              now: _now,
            ),
            _gap(),
            SurveyListItem(
              survey: _survey(
                name:
                    'A rather long survey name that has to wrap onto a '
                    'second line to be read at all',
                closesIn: const Duration(days: 4),
              ),
              isAdmin: true,
              hasParticipated: false,
              now: _now,
            ),
            const SectionLabel(label: 'Answered', count: 1),
            SurveyListItem(
              survey: _survey(
                name: 'Quarterly engagement',
                closesIn: const Duration(days: 5),
              ),
              isAdmin: false,
              hasParticipated: true,
              now: _now,
            ),
            const SectionLabel(label: 'Closed', count: 1),
            SurveyListItem(
              survey: _survey(
                name: 'Last year review',
                closesIn: const Duration(days: -20),
              ),
              isAdmin: true,
              hasParticipated: true,
              now: _now,
            ),
          ],
        ),
      );

      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/survey_rows_$name.png'),
      );
    });

    testWidgets('meeting rows in every state — $name', (tester) async {
      await _pump(
        tester,
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionLabel(label: 'Waiting on you', count: 2),
            AppointmentListItem(
              appointment: _appointment(
                title: 'Design review',
                closesIn: const Duration(days: 3),
                slots: [_slot(12, 10), _slot(13, 14), _slot(14, 9)],
              ),
              hasUserParticipated: false,
              isAdmin: true,
              isAnyTimeSLotConfirmed: false,
              now: _now,
            ),
            _gap(),
            AppointmentListItem(
              appointment: _appointment(
                title: 'Sprint planning',
                closesIn: const Duration(hours: 5),
                slots: [
                  _slot(11, 9),
                  _slot(11, 15),
                  _slot(12, 9),
                  _slot(12, 16),
                ],
                voters: 9,
              ),
              hasUserParticipated: false,
              isAdmin: false,
              isAnyTimeSLotConfirmed: false,
              now: _now,
            ),
            const SectionLabel(label: 'Answered', count: 1),
            AppointmentListItem(
              appointment: _appointment(
                title: 'All hands',
                closesIn: const Duration(days: 6),
                slots: [_slot(18, 16, confirmed: true), _slot(19, 11)],
                voters: 12,
              ),
              hasUserParticipated: true,
              isAdmin: false,
              isAnyTimeSLotConfirmed: true,
              now: _now,
            ),
            const SectionLabel(label: 'Closed', count: 1),
            AppointmentListItem(
              appointment: _appointment(
                title: 'Budget sync',
                closesIn: const Duration(days: -9),
                slots: [_slot(1, 10), _slot(2, 13)],
                voters: 6,
              ),
              hasUserParticipated: true,
              isAdmin: true,
              isAnyTimeSLotConfirmed: false,
              now: _now,
            ),
          ],
        ),
      );

      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/meeting_rows_$name.png'),
      );
    });
  }
}
