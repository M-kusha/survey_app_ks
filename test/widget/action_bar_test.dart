import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Size size, Widget home) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(
        tester.view,
      ).copyWith(disableAnimations: true),
      child: MaterialApp(theme: AppTheme.light, home: home),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _screen() => Scaffold(
  body: const SizedBox.expand(),
  bottomNavigationBar: WizardActionBar(
    maxWidth: 640,
    child: FilledButton(onPressed: () {}, child: const Text('Next')),
  ),
);

void main() {
  group('the form action', () {
    testWidgets('fills the width on a phone', (tester) async {
      await _pump(tester, const Size(393, 800), _screen());

      final button = tester.getSize(find.byType(FilledButton));

      expect(button.width, greaterThan(300));
    });

    testWidgets('does not stretch across a desktop', (tester) async {
      await _pump(tester, const Size(1500, 900), _screen());

      final button = tester.getSize(find.byType(FilledButton));

      expect(button.width, lessThan(200));
    });

    testWidgets('stays inside the content column on a desktop', (tester) async {
      await _pump(tester, const Size(1500, 900), _screen());

      final button = tester.getRect(find.byType(FilledButton));

      expect(button.right, lessThanOrEqualTo(1500 / 2 + 320));
    });
  });

  group('the bar itself', () {
    for (final size in [const Size(393, 800), const Size(1500, 900)]) {
      testWidgets('is only as tall as its button at ${size.width}', (
        tester,
      ) async {
        await _pump(tester, size, _screen());

        final bar = tester.getSize(find.byType(WizardActionBar));
        final button = tester.getSize(find.byType(FilledButton));

        expect(bar.height, lessThan(button.height + 60));
        expect(bar.height, lessThan(size.height / 4));
      });
    }

    testWidgets('leaves the body its space', (tester) async {
      await _pump(
        tester,
        const Size(393, 800),
        Scaffold(
          body: const Center(child: Text('body')),
          bottomNavigationBar: WizardActionBar(
            child: FilledButton(onPressed: () {}, child: const Text('Next')),
          ),
        ),
      );

      expect(find.text('body'), findsOneWidget);
      expect(tester.getSize(find.text('body')).height, greaterThan(0));
    });
  });

  group('the create button', () {
    Widget fabScreen() => Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: CreateFab(
        heroTag: 'test-create-fab',
        label: 'Add meeting',
        onPressed: () {},
      ),
    );

    testWidgets('is a plain circle on a phone', (tester) async {
      await _pump(tester, const Size(393, 800), fabScreen());

      expect(find.text('Add meeting'), findsNothing);
      final fab = tester.getSize(find.byType(FloatingActionButton));
      expect(fab.width, lessThanOrEqualTo(56));
    });

    testWidgets('carries its label where there is room', (tester) async {
      await _pump(tester, const Size(1100, 800), fabScreen());
      expect(find.text('Add meeting'), findsOneWidget);
    });
  });
}
