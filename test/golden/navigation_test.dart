import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

/// The navigation shell, with stand-in pages.
///
/// `BottomNavigation` takes a `pages` override precisely so it can be pumped
/// without Firebase — the real tabs all reach for it in `initState`.
Future<void> _pump(
  WidgetTester tester,
  ThemeData theme, {
  required Size size,
}) async {
  tester.view.physicalSize = size;
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
        home: BottomNavigation(
          initialIndex: 1,
          pages: [
            for (final label in ['notes', 'meetings', 'surveys', 'settings'])
              ColoredBox(
                color: theme.colorScheme.surface,
                child: Center(child: Text('page:$label')),
              ),
          ],
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

  testWidgets('phone shows the bottom bar', (tester) async {
    await _pump(tester, AppTheme.dark, size: const Size(393, 700));

    // Keyed rather than typed: the compact bar is this app's own widget now,
    // because Material's `NavigationBar` renders its label through a `Text` with
    // no `maxLines` and wrapped long labels onto a second line, pushing the icon
    // out of the bar.
    expect(find.byKey(bottomNavigationBarKey), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);

    await expectLater(
      find.byKey(bottomNavigationBarKey),
      matchesGoldenFile('goldens/nav_bar_dark.png'),
    );
  });

  testWidgets('desktop shows the rail, with its footer controls', (
    tester,
  ) async {
    await _pump(tester, AppTheme.dark, size: const Size(1200, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(bottomNavigationBarKey), findsNothing);

    await expectLater(
      find.byType(NavigationRail),
      matchesGoldenFile('goldens/nav_rail_dark.png'),
    );
  });

  testWidgets('tabs mount on first visit and then stay alive', (tester) async {
    await _pump(tester, AppTheme.light, size: const Size(393, 700));

    Finder page(String label) => find.text('page:$label', skipOffstage: false);

    expect(page('meetings'), findsOneWidget);
    expect(page('notes'), findsNothing);
    expect(page('surveys'), findsNothing);
    expect(page('settings'), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    await tester.pumpAndSettle();

    expect(page('notes'), findsOneWidget);
    expect(page('meetings'), findsOneWidget);
    expect(page('surveys'), findsNothing);
    expect(page('settings'), findsNothing);
  });
}
