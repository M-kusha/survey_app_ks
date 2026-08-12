import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the shape every list screen uses: a fixed header above a scrolling
/// list, inside [PageBody].
///
/// This is the exact mistake that blanked the notes, surveys and appointments
/// tabs — `PageBody` scrolls by default, an `Expanded` inside a scroll view has
/// unbounded height, and Flutter answers that with an exception instead of a
/// screen. It analyses clean, so only running it catches it.
Future<void> _pump(WidgetTester tester, Widget body) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: body),
    ),
  );
}

/// The list-screen shape: a fixed header, then a list that takes the rest.
///
/// `scrollable: false` is load-bearing, not stylistic. With PageBody's own
/// scroll view left on, the Column below has unbounded height and the Expanded
/// inside it throws — which is a blank tab, not a visible error.
Widget _listScreen({bool scrollable = false}) => PageBody(
  maxWidth: 720,
  scrollable: scrollable,
  child: Column(
    children: [
      const Text('header'),
      Expanded(
        child: ListView(
          children: const [SizedBox(height: 40, child: Text('row'))],
        ),
      ),
    ],
  ),
);

void main() {
  testWidgets('a header above a scrolling list renders', (tester) async {
    await _pump(tester, _listScreen(scrollable: false));

    expect(tester.takeException(), isNull);
    expect(find.text('header'), findsOneWidget);
    expect(find.text('row'), findsOneWidget);
  });

  testWidgets('a ContentCard lays out inside a list', (tester) async {
    // List items are given unbounded height, and a card that cannot size itself
    // under that constraint throws — which paints nothing in a release build
    // rather than showing an error. Every row in the app is one of these, so
    // this is the single most load-bearing layout in the product.
    await _pump(
      tester,
      ListView(
        children: [
          for (var i = 0; i < 3; i++)
            ContentCard(
              accent: i.isEven ? const Color(0xFF00FF00) : null,
              muted: i == 2,
              onTap: () {},
              child: Text('row $i'),
            ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('row 0'), findsOneWidget);
    expect(find.text('row 2'), findsOneWidget);
  });

  testWidgets('the accent colours the whole outline, not one edge', (
    tester,
  ) async {
    const accent = Color(0xFF00FF00);
    await _pump(
      tester,
      ListView(
        children: [
          const ContentCard(
            accent: accent,
            child: SizedBox(height: 120, child: Text('tall')),
          ),
        ],
      ),
    );

    // No coloured block anywhere: the stripe is gone. Two shapes were tried
    // before this. Full height was sliced by the 18px corner radius, leaving a
    // sliver in each corner and stacking with the progress rule at the bottom.
    // Inset by that radius it stopped short at both ends and read as a border
    // that had failed to finish drawing — which is what prompted replacing it.
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == accent ||
            widget is DecoratedBox &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).color == accent,
      ),
      findsNothing,
    );

    // The outline carries it instead, so it follows the corners exactly and has
    // no ends to get wrong at any card height.
    final outline = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.border)
        .whereType<Border>()
        .firstWhere((border) => border.top.color.a > 0);

    expect(outline.top.color.r, accent.r);
    expect(outline.top.color.g, accent.g);
    expect(outline.top.color.b, accent.b);
    // All four sides, or it is a stripe again by another name.
    for (final side in [
      outline.top,
      outline.bottom,
      outline.left,
      outline.right,
    ]) {
      expect(side.color.g, accent.g);
    }
  });

  testWidgets('cards still lay out in a list without a deadline rule', (
    tester,
  ) async {
    // `ContentCard` no longer takes a `progress`. The 2px part-filled line it
    // drew along the bottom edge was read as a broken border, and it repeated
    // the closing date the card already states in words — so it went, and this
    // test keeps the layout it used to guard.
    await _pump(
      tester,
      ListView(
        children: [
          for (final label in ['a', 'b', 'c'])
            ContentCard(
              accent: const Color(0xFF00FF00),
              child: Text('card $label'),
            ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('card b'), findsOneWidget);
  });

  testWidgets('the header, search pill and section label render together', (
    tester,
  ) async {
    await _pump(
      tester,
      PageBody(
        scrollable: false,
        child: Column(
          children: [
            ScreenHeader(
              title: 'Surveys',
              subtitle: '3 still open',
              actions: [CircleAction(icon: Icons.sort_rounded, onTap: () {})],
            ),
            SearchPill(controller: TextEditingController(), hint: 'Search'),
            const SectionLabel(label: 'Waiting on you', count: 2),
            const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Surveys'), findsOneWidget);
    expect(find.text('3 still open'), findsOneWidget);
    expect(find.text('WAITING ON YOU'), findsOneWidget);
  });

  testWidgets('PageBody keeps its own scrolling when nothing else does', (
    tester,
  ) async {
    await _pump(
      tester,
      PageBody(
        child: Column(children: [for (var i = 0; i < 40; i++) Text('line $i')]),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });
}
