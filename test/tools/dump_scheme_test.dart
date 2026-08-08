import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prints the generated colour schemes as JSON.
///
/// Not an assertion — a tool. Material derives the full palette from the seed
/// at runtime, so these values exist nowhere in the source. Dumping them is the
/// only way to give Figma the same numbers the app actually paints, rather than
/// a designer's approximation of them.
///
///     flutter test test/tools/dump_scheme_test.dart --plain-name dump
String _hex(Color c) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  return '#'
      '${ch(c.r).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.g).toRadixString(16).padLeft(2, '0')}'
      '${ch(c.b).toRadixString(16).padLeft(2, '0')}';
}

Map<String, String> _scheme(ColorScheme s) => {
  'primary': _hex(s.primary),
  'onPrimary': _hex(s.onPrimary),
  'primaryContainer': _hex(s.primaryContainer),
  'onPrimaryContainer': _hex(s.onPrimaryContainer),
  'secondary': _hex(s.secondary),
  'onSecondary': _hex(s.onSecondary),
  'secondaryContainer': _hex(s.secondaryContainer),
  'onSecondaryContainer': _hex(s.onSecondaryContainer),
  'tertiary': _hex(s.tertiary),
  'onTertiary': _hex(s.onTertiary),
  'tertiaryContainer': _hex(s.tertiaryContainer),
  'onTertiaryContainer': _hex(s.onTertiaryContainer),
  'error': _hex(s.error),
  'onError': _hex(s.onError),
  'errorContainer': _hex(s.errorContainer),
  'onErrorContainer': _hex(s.onErrorContainer),
  'surface': _hex(s.surface),
  'onSurface': _hex(s.onSurface),
  'onSurfaceVariant': _hex(s.onSurfaceVariant),
  'surfaceContainerLowest': _hex(s.surfaceContainerLowest),
  'surfaceContainerLow': _hex(s.surfaceContainerLow),
  'surfaceContainer': _hex(s.surfaceContainer),
  'surfaceContainerHigh': _hex(s.surfaceContainerHigh),
  'surfaceContainerHighest': _hex(s.surfaceContainerHighest),
  'outline': _hex(s.outline),
  'outlineVariant': _hex(s.outlineVariant),
  'inverseSurface': _hex(s.inverseSurface),
  'onInverseSurface': _hex(s.onInverseSurface),
};

Map<String, String> _semantic(AppColors a) => {
  'success': _hex(a.success),
  'onSuccess': _hex(a.onSuccess),
  'successContainer': _hex(a.successContainer),
  'warning': _hex(a.warning),
  'onWarning': _hex(a.onWarning),
  'warningContainer': _hex(a.warningContainer),
  'info': _hex(a.info),
  'infoContainer': _hex(a.infoContainer),
  'participated': _hex(a.participated),
  'notParticipated': _hex(a.notParticipated),
  'pending': _hex(a.pending),
};

void main() {
  test('dump', () {
    final out = {
      'light': {
        'scheme': _scheme(AppTheme.light.colorScheme),
        'semantic': _semantic(AppColors.light),
      },
      'dark': {
        'scheme': _scheme(AppTheme.dark.colorScheme),
        'semantic': _semantic(AppColors.dark),
      },
    };

    final buffer = StringBuffer('===SCHEME_START===\n');
    out.forEach((mode, groups) {
      (groups).forEach((group, values) {
        values.forEach((k, v) => buffer.writeln('$mode.$group.$k=$v'));
      });
    });
    buffer.write('===SCHEME_END===');
    // ignore: avoid_print
    print(buffer);
  });
}
