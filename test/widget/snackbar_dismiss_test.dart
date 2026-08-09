import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Why the undo notice after deleting a note would not go away.
///
/// Flutter does not start the auto-dismiss timer for a snackbar that carries an
/// action while accessible navigation is on, so that somebody using a screen
/// reader has time to reach the button. Sensible in itself; the effect on
/// everyone else is a bar that stays put until they press the very action they
/// were trying to avoid — which is exactly what was reported.
///
/// The flag cannot be set from the test: `MaterialApp` inserts its own
/// `MediaQuery.fromView`, which replaces anything wrapped around it, and the
/// test binding reports accessible navigation as on. So these run in that mode
/// and pin the behaviour there — which is the mode that was broken.
Future<void> _pump(
  WidgetTester tester, {
  required bool withAction,
  required bool showCloseIcon,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Note deleted'),
                showCloseIcon: showCloseIcon,
                action: withAction
                    ? SnackBarAction(label: 'Undo', onPressed: () {})
                    : null,
              ),
            ),
            child: const Text('delete'),
          ),
        ),
      ),
    ),
  );
}

/// Entrance, then its four-second life, then the exit.
///
/// Not one long pump: the dismiss timer is only created once the entrance
/// animation reports completed, so a single jump past four seconds lands before
/// the timer exists and nothing ever fires. Getting this wrong first made a
/// perfectly healthy snackbar look broken and sent me after the wrong cause.
Future<void> _waitOut(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a snackbar with no action clears itself', (tester) async {
    await _pump(tester, withAction: false, showCloseIcon: false);

    await tester.tap(find.text('delete'));
    await tester.pump();
    expect(find.text('Note deleted'), findsOneWidget);

    await _waitOut(tester);
    expect(find.text('Note deleted'), findsNothing);
  });

  testWidgets('one with an action does not — this was the bug', (tester) async {
    await _pump(tester, withAction: true, showCloseIcon: false);

    await tester.tap(find.text('delete'));
    await tester.pump();
    await _waitOut(tester);

    // Deliberate on Flutter's part, and the reason the notice sat there until
    // the user pressed Undo or reloaded the page.
    expect(find.text('Note deleted'), findsOneWidget);
  });

  testWidgets('a close icon gives it a way out', (tester) async {
    await _pump(tester, withAction: true, showCloseIcon: true);

    await tester.tap(find.text('delete'));
    await tester.pump();
    await _waitOut(tester);

    expect(find.text('Note deleted'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('Note deleted'), findsNothing);
  });
}
