import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
