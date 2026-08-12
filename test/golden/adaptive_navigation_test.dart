import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/load_translations.dart';

const _viewports = <String, Size>{
  'compact_phone': Size(390, 844),
  'medium_tablet_portrait': Size(768, 1024),
  'expanded_tablet_landscape': Size(1024, 768),
  'large_desktop': Size(1440, 900),
};

Widget _stubPage(String label, Color color) => ColoredBox(
  color: color,
  child: Center(
    child: PageBody(
      centerVertically: true,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: Spacing.md),
              const Text(
                'PageBody keeps this column at a readable width instead of '
                'letting it span the whole window.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF004B96),
          secondary: Colors.grey,
        ),
      ),
      home: BottomNavigation(
        pages: [
          _stubPage('Notes', const Color(0xFFF4F6F8)),
          _stubPage('Appointments', const Color(0xFFF4F6F8)),
          _stubPage('Surveys', const Color(0xFFF4F6F8)),
          _stubPage('Settings', const Color(0xFFF4F6F8)),
        ],
      ),
    ),
  );

  await tester.pumpAndSettle();

  expect(
    find.byType(BottomNavigation),
    findsOneWidget,
    reason: 'the navigation shell did not render',
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    SharedPreferences.setMockInitialValues({});

    await loadAppTranslations();
  });

  group('adaptive navigation', () {
    _viewports.forEach((name, size) {
      testWidgets('renders at $name', (tester) async {
        await _pumpAt(tester, size);
        await expectLater(
          find.byType(BottomNavigation),
          matchesGoldenFile('goldens/nav_$name.png'),
        );
      });
    });

    testWidgets('a phone gets a bottom bar and no rail', (tester) async {
      await _pumpAt(tester, _viewports['compact_phone']!);

      expect(find.byKey(bottomNavigationBarKey), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('a tablet gets a rail and no bottom bar', (tester) async {
      await _pumpAt(tester, _viewports['medium_tablet_portrait']!);
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byKey(bottomNavigationBarKey), findsNothing);
    });

    testWidgets('the rail only extends on a large window', (tester) async {
      await _pumpAt(tester, _viewports['expanded_tablet_landscape']!);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isFalse,
      );

      await _pumpAt(tester, _viewports['large_desktop']!);
      expect(
        tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
        isTrue,
      );
    });

    testWidgets('every tab stays alive across a switch', (tester) async {
      await _pumpAt(tester, _viewports['compact_phone']!);

      expect(find.byType(IndexedStack), findsOneWidget);
      final stack = tester.widget<IndexedStack>(find.byType(IndexedStack));
      expect(stack.children.length, 4);
      expect(stack.index, 0);
    });
  });

  group('window size classes', () {
    test('boundaries land where Material 3 puts them', () {
      expect(WindowSize.fromWidth(599), WindowSize.compact);
      expect(WindowSize.fromWidth(600), WindowSize.medium);
      expect(WindowSize.fromWidth(839), WindowSize.medium);
      expect(WindowSize.fromWidth(840), WindowSize.expanded);
      expect(WindowSize.fromWidth(1199), WindowSize.expanded);
      expect(WindowSize.fromWidth(1200), WindowSize.large);
    });

    test('only compact uses a bottom bar', () {
      expect(WindowSize.compact.usesBottomNavigation, isTrue);
      expect(WindowSize.medium.usesBottomNavigation, isFalse);
      expect(WindowSize.expanded.usesBottomNavigation, isFalse);
      expect(WindowSize.large.usesBottomNavigation, isFalse);
    });

    test('two panes need expanded or larger', () {
      expect(WindowSize.compact.canShowTwoPanes, isFalse);
      expect(WindowSize.medium.canShowTwoPanes, isFalse);
      expect(WindowSize.expanded.canShowTwoPanes, isTrue);
      expect(WindowSize.large.canShowTwoPanes, isTrue);
    });

    test('text scale grows with the window and never shrinks below 1', () {
      final scales = WindowSize.values.map((s) => s.textScale).toList();
      expect(scales.first, 1.0);
      for (var i = 1; i < scales.length; i++) {
        expect(scales[i], greaterThan(scales[i - 1]));
      }
    });
  });
}
