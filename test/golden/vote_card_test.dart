import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/participants/vote_slot_card.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

final _fixed = DateTime(2025, 3, 12, 14);

TimeSlot _slot(int day, {bool confirmed = false}) => TimeSlot(
  slotId: 'slot-$day',
  start: DateTime(2025, 3, day, 14),
  end: DateTime(2025, 3, day, 15),
  isConfirmed: confirmed,
);

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  tester.view.physicalSize = const Size(520, 1000);
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
    testWidgets('vote cards in every state — $name', (tester) async {
      await _pump(
        tester,
        theme,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Leading, voted yes, admin can confirm.
            VoteSlotCard(
              slot: _slot(12),
              zoneId: 'Europe/Berlin',
              tally: SlotTally(
                slotId: 'slot-12',
                start: _fixed,
                yes: 5,
                maybe: 2,
                no: 1,
              ),
              myStatus: VoteStatus.yes,
              isLeader: true,
              isTied: false,
              enabled: true,
              onChoose: (_) {},
              onShowVoters: () {},
              onConfirm: () {},
            ),
            const SizedBox(height: Spacing.md),
            // Nobody has answered: no bar at all, rather than an empty one.
            VoteSlotCard(
              slot: _slot(13),
              zoneId: 'Europe/Berlin',
              tally: SlotTally(
                slotId: 'slot-13',
                start: _fixed,
                yes: 0,
                maybe: 0,
                no: 0,
              ),
              myStatus: null,
              isLeader: false,
              isTied: false,
              enabled: true,
              onChoose: (_) {},
              onShowVoters: () {},
            ),
            const SizedBox(height: Spacing.md),
            // Voting closed: buttons visibly inert, counts still readable.
            VoteSlotCard(
              slot: _slot(14, confirmed: true),
              zoneId: 'Europe/Berlin',
              tally: SlotTally(
                slotId: 'slot-14',
                start: _fixed,
                yes: 3,
                maybe: 0,
                no: 4,
              ),
              myStatus: VoteStatus.no,
              isLeader: false,
              isTied: false,
              enabled: false,
              onChoose: (_) {},
              onShowVoters: () {},
            ),
          ],
        ),
      );

      await expectLater(
        find.byType(Column).first,
        matchesGoldenFile('goldens/vote_cards_$name.png'),
      );
    });
  }
}
