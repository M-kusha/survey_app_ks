import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative-luminance contrast, so "can you see the card" is a number.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = first > second ? first : second;
  final darker = first > second ? second : first;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  final light = AppTheme.light.colorScheme;
  final dark = AppTheme.dark.colorScheme;

  test('a card is a different tone from the page it sits on', () {
    // Material 3's default arrangement puts a card on `surface`, which in light
    // mode is #F3F3FA on #F9F9FF — a contrast of 1.05, invisible. A screen of
    // those reads as blank, which is the complaint this whole arrangement
    // exists to answer.
    for (final scheme in [light, dark]) {
      expect(scheme.cardSurface, isNot(scheme.pageSurface));
      expect(scheme.mutedCardSurface, isNot(scheme.cardSurface));
    }

    expect(
      _contrast(light.cardSurface, light.pageSurface),
      greaterThan(1.1),
      reason: 'a light-mode card must be visible against its page',
    );
  });

  test('light lifts cards off the page, dark keeps Material’s direction', () {
    // Light mode tints the page and raises cards to white. Dark mode leaves the
    // default alone: a lighter panel on a darker page already separates, and
    // flipping it would sink cards below the page for nothing.
    expect(
      light.cardSurface.computeLuminance(),
      greaterThan(light.pageSurface.computeLuminance()),
    );
    expect(
      dark.cardSurface.computeLuminance(),
      greaterThan(dark.pageSurface.computeLuminance()),
    );
  });

  test('a muted card recedes rather than advancing', () {
    // The bug this replaced: `muted` resolved to `surfaceContainerLowest`,
    // which in light mode is pure white — so an expired survey was the
    // brightest thing on the page.
    expect(
      light.mutedCardSurface.computeLuminance(),
      lessThan(light.cardSurface.computeLuminance()),
    );
    expect(
      dark.mutedCardSurface.computeLuminance(),
      lessThan(dark.cardSurface.computeLuminance()),
    );
  });

  test('only light mode pays for a shadow', () {
    // In dark mode a shadow is a darker smudge on an already dark page.
    expect(light.cardElevation, greaterThan(0));
    expect(dark.cardElevation, 0);
  });

  test('the scaffold and app bar use the page tone', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final scheme = theme.colorScheme;
      expect(theme.scaffoldBackgroundColor, scheme.pageSurface);
      expect(theme.appBarTheme.backgroundColor, scheme.pageSurface);
      expect(theme.cardTheme.color, scheme.cardSurface);
    }
  });
}
