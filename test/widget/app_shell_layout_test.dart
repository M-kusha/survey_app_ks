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
Future<void> _pumpShell(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // No `EasyLocalization` widget: it loads its assets asynchronously off the
  // test clock, so a second mount in the same file settles before the tree
  // exists. `loadAppTranslations` primes the same static the widget would.
  await tester.pumpWidget(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => FontSizeProvider())],
      child: const MaterialApp(
        home: BottomNavigation(
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
}
