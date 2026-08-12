import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/load_translations.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  required double width,
  double textScale = 1,
}) async {
  tester.view.physicalSize = Size(width, 780);
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

  for (final width in [320.0, 360.0, 384.0, 412.0]) {
    testWidgets('every label is one line at ${width.toInt()}px', (
      tester,
    ) async {
      await _pumpShell(tester, width: width);

      expect(tester.takeException(), isNull);

      for (final label in ['Notes', 'Meetings', 'Surveys', 'Settings']) {
        final found = find.text(label);
        expect(found, findsOneWidget, reason: 'missing the $label label');
        expect(
          tester.getSize(found).height,
          lessThanOrEqualTo(20),
          reason: '$label wrapped at ${width.toInt()}px',
        );
      }
    });
  }

  testWidgets('labels truncate rather than wrap at a large font size', (
    tester,
  ) async {
    await _pumpShell(tester, width: 320, textScale: 3);

    expect(tester.takeException(), isNull);

    final label = tester.widget<Text>(find.text('Meetings'));
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(label.softWrap, isFalse);
  });

  testWidgets('page content still honours the reader font size', (
    tester,
  ) async {
    await _pumpShell(tester, width: 320, textScale: 3);

    final scaler = MediaQuery.textScalerOf(tester.element(find.text('notes')));
    expect(scaler.scale(12), 36);
  });

  testWidgets('tapping a destination switches the page', (tester) async {
    await _pumpShell(tester, width: 384);

    await tester.tap(find.text('Surveys'));
    await tester.pumpAndSettle();

    expect(find.text('surveys'), findsOneWidget);
  });

  testWidgets('the selected destination is announced as selected', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await _pumpShell(tester, width: 384);

    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Notes'))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('Surveys'))
          .flagsCollection
          .isSelected,
      Tristate.isFalse,
    );

    semantics.dispose();
  });
}
