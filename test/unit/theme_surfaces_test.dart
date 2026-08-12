import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
