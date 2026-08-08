import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Compatibility shim over the Material 3 theme.
///
/// This used to be two hand-written `Map<String, Color>` literals — one per
/// brightness — that had drifted apart: the *light* map set `textColor: white`
/// and `cardColor: grey[800]`, and the dark map used grey for both primary and
/// secondary. A mistyped key returned `Colors.blue` with no complaint.
///
/// The keys now resolve against the real `ColorScheme`, so the handful of
/// screens still calling this are themed correctly without having to be edited
/// all at once. New code should use `Theme.of(context).colorScheme` or
/// `context.appColors` directly.
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
      // Previously `Colors.blue`, which meant a typo produced a plausible
      // colour and was never noticed. A magenta is unmistakable in review.
      _ => const Color(0xFFFF00FF),
    };
  }
}
