import 'package:echomeet/core/widgets/sign_out_button.dart';
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
    // A phone held sideways. 832x384 is a Galaxy S25 Ultra in landscape, which
    // is `medium` — so it gets the rail, in a viewport too short for four
    // destinations plus the profile block and the footer. The rail overflowed
    // there, which is the reported landscape overflow; it is fixed by letting
    // the destination group scroll.
    ('a phone in landscape', Size(832, 384)),
    // Landscape with the system font enlarged, which is the same squeeze again
    // with taller destinations.
    ('a small phone in landscape', Size(740, 340)),
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

  testWidgets('the rail footer sits at the bottom, not under the tabs', (
    tester,
  ) async {
    // `NavigationRail.trailingAtBottom` defaults to false, which places the
    // trailing widget inside the scrolling destination group — so turning on
    // `scrollable` to fix the landscape overflow moved the theme, language and
    // sign-out controls up under the last tab. No exception is thrown when that
    // happens, so only a position assertion catches it.
    await _pumpShell(tester, const Size(1000, 800));

    final rail = tester.getRect(find.byType(NavigationRail));
    final footer = tester.getRect(find.byType(SignOutButton));

    expect(
      footer.center.dy,
      greaterThan(rail.center.dy),
      reason: 'the footer rode up into the destination group',
    );
    expect(rail.bottom - footer.bottom, lessThan(80));
  });

  // The bottom bar's own behaviour — one-line labels, truncation, the scale cap
  // and its semantics — lives in `bottom_navigation_label_test.dart`, which
  // targets the widget directly. It used to be asserted here against Material's
  // `NavigationBar`, which this app no longer uses.
}
