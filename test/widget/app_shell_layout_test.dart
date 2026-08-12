import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/load_translations.dart';

/// The shell at every window size, with no providers beyond the one it cannot
/// start without.
///
/// The rail is an unconstrained child of the shell's `Row`, because
/// `NavigationRail` sizes itself from its destinations. Anything flexible placed
/// in its `leading` therefore lays out against an unbounded width and throws
/// `RenderFlex children have non-zero flex but incoming width constraints are
/// unbounded` — which is a red screen on the way in, on desktop only, so it does
/// not show up on a phone or in a narrow test.
Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // No `EasyLocalization` widget: it loads its assets asynchronously off the
  // test clock, so a second mount in the same file settles before the tree
  // exists. `loadAppTranslations` primes the same static the widget would.
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => FontSizeProvider())],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const BottomNavigation(
          pages: [
            Text('notes'),
            Text('meetings'),
            Text('surveys'),
            Text('settings'),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppTranslations();
  });

  for (final (name, size) in [
    ('a large window, extended rail', Size(1440, 900)),
    // 1285x730 is the size the reported crash came from.
    ('the size the crash was reported at', Size(1286, 730)),
    ('an expanded window, collapsed rail', Size(1000, 800)),
    ('a medium window', Size(700, 900)),
    ('a compact window, bottom bar', Size(400, 900)),
  ]) {
    testWidgets('the shell lays out in $name', (tester) async {
      await _pumpShell(tester, size);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the account block survives having no user providers', (
    tester,
  ) async {
    // The rail is chrome. It reads the signed-in account when it is there and
    // draws a plain avatar when it is not, rather than taking the shell down.
    await _pumpShell(tester, const Size(1440, 900));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('the bottom bar holds its label size at any system scale', (
    tester,
  ) async {
    // At the largest system font size "Appointments" wrapped onto two lines and
    // pushed its icon up out of the bar. Truncation is not reachable: Flutter
    // wraps the label in its own `AnimatedDefaultTextStyle` with
    // `overflow: clip`, which beats any ambient `DefaultTextStyle`. Holding the
    // scale is what keeps it on one line, so that is what gets pinned.
    await _pumpShell(tester, const Size(400, 900), textScale: 3);

    expect(tester.takeException(), isNull);

    final scaler = MediaQuery.textScalerOf(
      tester.element(find.byType(NavigationBar)),
    );
    expect(scaler.scale(12), 12);
  });

  testWidgets('page content still honours the reader font size', (
    tester,
  ) async {
    // The cap is chrome-only. Scaling the whole app down to keep four labels
    // tidy would be a bad trade, so this fails if the clamp ever leaks past the
    // bar into the page.
    await _pumpShell(tester, const Size(400, 900), textScale: 3);

    final scaler = MediaQuery.textScalerOf(tester.element(find.text('notes')));
    expect(scaler.scale(12), 36);
  });
}
