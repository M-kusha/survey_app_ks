import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

@Deprecated(
  'Use Theme.of(context).colorScheme or context.appColors. '
  'This exists so screens not yet migrated keep rendering correctly.',
)
class ThemeBasedAppColors {
  static Color getColor(BuildContext context, String colorKey) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.appColors;

    return switch (colorKey) {
      'primary' => scheme.primary,
      'secondary' => scheme.secondary,
      'buttonColor' => scheme.primary,
      'listTileColor' => scheme.onSurface,
      'textColor' => scheme.onPrimary,
      'appbarColor' => scheme.surface,
      'selectedColor' => scheme.primaryContainer,
      'errorColor' => scheme.error,
      'snackBarColor' => scheme.inverseSurface,
      'dateColor' => scheme.onSurfaceVariant,
      'listparticipatedColor' => app.participated,
      'listnotparticipatedColor' => app.notParticipated,
      'cameraIconColor' => scheme.onSurfaceVariant,
      'cardColor' => scheme.surfaceContainerLow,
      'iconColor' => scheme.onSurfaceVariant,

      _ => const Color(0xFFFF00FF),
    };
  }
}
