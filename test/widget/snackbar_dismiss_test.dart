import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
