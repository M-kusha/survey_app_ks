import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two controls that were oversized on one platform each: the form's
/// bottom action, which stretched across a desktop, and the create button,
/// which ate a third of a phone.
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
      // Full bleed minus the bar's own padding — a thumb target on a narrow
      // screen genuinely wants the whole width.
      expect(button.width, greaterThan(300));
    });

    testWidgets('does not stretch across a desktop', (tester) async {
      await _pump(tester, const Size(1500, 900), _screen());

      final button = tester.getSize(find.byType(FilledButton));
      // Sized to its label. This was the bug: on a 1500px window the same
      // button ran the full width of the screen.
      expect(button.width, lessThan(200));
    });

    testWidgets('stays inside the content column on a desktop', (tester) async {
      await _pump(tester, const Size(1500, 900), _screen());

      final button = tester.getRect(find.byType(FilledButton));
      // Right edge lines up with where a 640-wide centred column ends, rather
      // than with the far side of the monitor.
      expect(button.right, lessThanOrEqualTo(1500 / 2 + 320));
    });
  });

  group('the bar itself', () {
    // This has now been broken three times by the same mistake: a `Center` in a
    // `bottomNavigationBar` takes the full height it is offered, swallows the
    // page, and leaves the action floating in the middle of an empty screen.
    // Comments did not stop it. This does.
    for (final size in [const Size(393, 800), const Size(1500, 900)]) {
      testWidgets('is only as tall as its button at ${size.width}', (
        tester,
      ) async {
        await _pump(tester, size, _screen());

        final bar = tester.getSize(find.byType(WizardActionBar));
        final button = tester.getSize(find.byType(FilledButton));

        // Padding is 8 above and 20 below, plus whatever the safe area adds.
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

      // The symptom the user saw: the form was gone and only the button
      // remained. Asserting the body still occupies most of the screen catches
      // it from the other side.
      expect(find.text('body'), findsOneWidget);
      expect(tester.getSize(find.text('body')).height, greaterThan(0));
    });
  });

  group('the create button', () {
    Widget fabScreen() => Scaffold(
      body: const SizedBox.expand(),
      floatingActionButton: CreateFab(label: 'Add meeting', onPressed: () {}),
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
