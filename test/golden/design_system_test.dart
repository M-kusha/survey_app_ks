import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) async {
  tester.view.physicalSize = const Size(900, 1500);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(Spacing.xl),
          child: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _section(String title, List<Widget> children) => Padding(
  padding: const EdgeInsets.only(bottom: Spacing.xl),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: Spacing.md),
      Wrap(spacing: Spacing.md, runSpacing: Spacing.md, children: children),
    ],
  ),
);

Widget _swatch(String name, Color color, Color on) => Container(
  width: 132,
  height: 56,
  padding: const EdgeInsets.all(Spacing.sm),
  decoration: BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(Radii.sm),
  ),
  alignment: Alignment.bottomLeft,
  child: Text(name, style: TextStyle(color: on, fontSize: 11)),
);

Widget _gallery(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final app = context.appColors;
  final text = Theme.of(context).textTheme;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _section('Scheme — generated from one seed', [
        _swatch('primary', scheme.primary, scheme.onPrimary),
        _swatch(
          'primaryContainer',
          scheme.primaryContainer,
          scheme.onPrimaryContainer,
        ),
        _swatch('secondary', scheme.secondary, scheme.onSecondary),
        _swatch(
          'secondaryContainer',
          scheme.secondaryContainer,
          scheme.onSecondaryContainer,
        ),
        _swatch('tertiary', scheme.tertiary, scheme.onTertiary),
        _swatch('error', scheme.error, scheme.onError),
        _swatch(
          'errorContainer',
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      ]),
      _section('Surfaces — depth without shadows', [
        _swatch('surface', scheme.surface, scheme.onSurface),
        _swatch(
          'surfaceContainerLow',
          scheme.surfaceContainerLow,
          scheme.onSurface,
        ),
        _swatch('surfaceContainer', scheme.surfaceContainer, scheme.onSurface),
        _swatch(
          'surfaceContainerHigh',
          scheme.surfaceContainerHigh,
          scheme.onSurface,
        ),
        _swatch(
          'surfaceContainerHighest',
          scheme.surfaceContainerHighest,
          scheme.onSurface,
        ),
      ]),
      _section('Semantic — what Material has no slot for', [
        _swatch('success', app.success, app.onSuccess),
        _swatch('successContainer', app.successContainer, scheme.onSurface),
        _swatch('warning', app.warning, app.onWarning),
        _swatch('warningContainer', app.warningContainer, scheme.onSurface),
        _swatch('info', app.info, scheme.onPrimary),
        _swatch('participated', app.participated, app.onSuccess),
        _swatch('notParticipated', app.notParticipated, scheme.onError),
        _swatch('pending', app.pending, scheme.onPrimary),
      ]),
      _section('Buttons', [
        FilledButton(onPressed: () {}, child: const Text('Filled')),
        ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
        OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
        TextButton(onPressed: () {}, child: const Text('Text')),
        const ElevatedButton(onPressed: null, child: Text('Disabled')),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('With icon'),
        ),
      ]),
      _section('Typography', [
        SizedBox(
          width: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Headline small', style: text.headlineSmall),
              Text('Title large', style: text.titleLarge),
              Text('Title medium', style: text.titleMedium),
              Text('Body large', style: text.bodyLarge),
              Text(
                'Body medium — the reading size, with line height tuned for '
                'paragraphs rather than labels.',
                style: text.bodyMedium,
              ),
              Text(
                'Body small, used for secondary detail',
                style: text.bodySmall,
              ),
              Text('LABEL LARGE', style: text.labelLarge),
            ],
          ),
        ),
      ]),
      _section('Inputs', [
        const SizedBox(
          width: 260,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Email',
              hintText: 'you@work.com',
            ),
          ),
        ),
        const SizedBox(
          width: 260,
          child: TextField(
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: 'Incorrect password',
            ),
          ),
        ),
        SizedBox(
          width: 300,
          child: Row(
            children: [
              Checkbox(value: true, onChanged: (_) {}),
              const Flexible(child: Text('Remember me')),
              const SizedBox(width: Spacing.sm),
              Switch(value: true, onChanged: (_) {}),
            ],
          ),
        ),
      ]),
      _section('Containers', [
        SizedBox(
          width: 260,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(Spacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Q1 review', style: text.titleMedium),
                  const SizedBox(height: Spacing.xs),
                  Text('8 questions · 12 responses', style: text.bodySmall),
                ],
              ),
            ),
          ),
        ),
        Wrap(
          spacing: Spacing.sm,
          children: [
            const Chip(label: Text('Draft')),
            Chip(
              label: const Text('Answered'),
              backgroundColor: app.successContainer,
            ),
            Chip(
              label: const Text('Awaiting review'),
              backgroundColor: app.warningContainer,
            ),
          ],
        ),
        SizedBox(
          width: 260,
          child: LinearProgressIndicator(
            value: 0.62,
            borderRadius: BorderRadius.circular(Radii.full),
          ),
        ),
      ]),
    ],
  );
}

void main() {
  group('design system', () {
    testWidgets('light', (tester) async {
      await _pump(tester, AppTheme.light, Builder(builder: _gallery));
      await expectLater(
        find.byType(SingleChildScrollView),
        matchesGoldenFile('goldens/design_system_light.png'),
      );
    });

    testWidgets('dark', (tester) async {
      await _pump(tester, AppTheme.dark, Builder(builder: _gallery));
      await expectLater(
        find.byType(SingleChildScrollView),
        matchesGoldenFile('goldens/design_system_dark.png'),
      );
    });
  });

  group('theme wiring', () {
    test('both themes carry the semantic palette', () {
      expect(AppTheme.light.extension<AppColors>(), isNotNull);
      expect(AppTheme.dark.extension<AppColors>(), isNotNull);
    });

    test('both are Material 3 and share one seed', () {
      expect(AppTheme.light.useMaterial3, isTrue);
      expect(AppTheme.dark.useMaterial3, isTrue);
      expect(AppTheme.light.colorScheme.brightness, Brightness.light);
      expect(AppTheme.dark.colorScheme.brightness, Brightness.dark);
    });

    test('dark mode never paints on pure black', () {
      expect(AppTheme.dark.colorScheme.surface, isNot(const Color(0xFF000000)));
      expect(AppTheme.dark.scaffoldBackgroundColor, isNot(Colors.black));
    });
  });
}
