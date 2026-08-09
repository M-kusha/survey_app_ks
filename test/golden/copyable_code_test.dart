import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/localization/app_locales.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/copyable_code.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_fonts.dart';
import '../support/load_translations.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  tester.view.physicalSize = const Size(460, 420);
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
          body: Padding(
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

  testWidgets('the code, and the buttons beside it, at their real size', (
    tester,
  ) async {
    await _pump(
      tester,
      AppTheme.dark,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CopyableCode(label: 'Meeting ID', code: 'aB3xK9mQ72ZpLw4n'),
          const SizedBox(height: Spacing.xl),
          Center(
            child: FilledButton(onPressed: () {}, child: const Text('Finish')),
          ),
          const SizedBox(height: Spacing.md),
          FilledButton(onPressed: () {}, child: const Text('Full width')),
          const SizedBox(height: Spacing.md),
          OutlinedButton(onPressed: () {}, child: const Text('Secondary')),
        ],
      ),
    );

    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/copy_and_buttons_dark.png'),
    );
  });

  testWidgets('tapping writes the raw code and confirms in place', (
    tester,
  ) async {
    // The clipboard is a platform channel; capture it rather than hoping.
    String? written;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          written = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(
      tester,
      AppTheme.dark,
      const CopyableCode(label: 'Meeting ID', code: 'aB3xK9mQ72ZpLw4n'),
    );

    await tester.tap(find.byType(CopyableCode));
    await tester.pump();

    // Grouped for reading, ungrouped on the clipboard — pasting an id with
    // spaces in it would not match anything.
    expect(written, 'aB3xK9mQ72ZpLw4n');
    expect(find.text('copied'.tr()), findsOneWidget);

    // Let the two-second reset run out, or the test ends with a pending timer.
    // Worth asserting anyway: the label has to go back, and the widget has to
    // survive doing so.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('copied'.tr()), findsNothing);
    expect(find.text('Meeting ID'), findsOneWidget);
  });
}
