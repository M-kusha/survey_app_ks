import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/load_translations.dart';

/// The bottom bar must keep its height whatever the label, locale or font size.
///
/// The reported bug: at a large system font size, and then again at ordinary
/// phone widths, "Appointments" wrapped onto a second line and pushed its icon
/// up out of the bar. Material's `NavigationBar` cannot prevent that from
/// outside — its label is a String rendered by a `Text` with no `maxLines`,
/// inside a `Material` that installs a fresh `DefaultTextStyle` — so the bar is
/// this app's own widget. These tests pin the properties that replacement was
/// built for.
///
/// Note on measurement: the default test font draws every glyph at a fixed
/// ~12.5px, about double Inter's real average, so *width* comparisons here mean
/// nothing about a real device. Height and overflow do, which is why the
/// assertions are about those.
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

      // One line of labelMedium is 16px in the test font. Two would be 32 and
      // would not fit above the icon — which is the reported failure.
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
    // Scale 3 is the system maximum. The cap holds the chrome near its designed
    // size, and the ellipsis catches whatever the cap still lets through, so
    // neither the height nor the icon position depends on this setting.
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
    // The cap is chrome-only, or the whole app would shrink to keep four labels
    // tidy. This is the trade that must not silently reverse.
    await _pumpShell(tester, width: 320, textScale: 3);

    final scaler = MediaQuery.textScalerOf(tester.element(find.text('notes')));
    expect(scaler.scale(12), 36);
  });

  testWidgets('tapping a destination switches the page', (tester) async {
    // A hand-rolled bar has to keep doing the one thing the bar is for.
    await _pumpShell(tester, width: 384);

    await tester.tap(find.text('Surveys'));
    await tester.pumpAndSettle();

    expect(find.text('surveys'), findsOneWidget);
  });

  testWidgets('the selected destination is announced as selected', (
    tester,
  ) async {
    // Replacing Material's destinations means replacing their semantics too, or
    // the bar becomes four unlabelled buttons to a screen reader.
    //
    // The handle is required: without it the semantics tree is only built if
    // something else in the isolate happened to enable it, so this passed alone
    // and failed in a full run.
    final semantics = tester.ensureSemantics();

    await _pumpShell(tester, width: 384);

    // By semantics label, not by text: each destination is a single semantics
    // node that replaces its children's, so the label is what a screen reader
    // actually reaches.
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
