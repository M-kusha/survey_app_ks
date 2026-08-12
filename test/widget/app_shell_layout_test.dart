import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/load_translations.dart';

Future<void> _pumpShell(
  WidgetTester tester,
  Size size, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
    ('the size the crash was reported at', Size(1286, 730)),
    ('an expanded window, collapsed rail', Size(1000, 800)),
    ('a medium window', Size(700, 900)),
    ('a compact window, bottom bar', Size(400, 900)),

    ('a phone in landscape', Size(832, 384)),

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
    await _pumpShell(tester, const Size(1440, 900));

    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('the rail footer sits at the bottom, not under the tabs', (
    tester,
  ) async {
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
}
