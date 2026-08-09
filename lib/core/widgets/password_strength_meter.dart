import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:password_strength/password_strength.dart';

class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});

  final String password;

  static const minimum = 0.3;

  static bool isStrongEnough(String password) =>
      estimatePasswordStrength(password) >= minimum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;
    final strength = estimatePasswordStrength(password);

    final (labelKey, color) = switch (strength) {
      _ when strength < minimum => ('password_weak', theme.colorScheme.error),
      _ when strength < 0.6 => ('password_fair', app.warning),
      _ => ('password_strong', app.success),
    };

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              tween: Tween(begin: 0, end: strength),
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 4,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.md),
        Text(
          '${'password_strength'.tr()}: ${labelKey.tr()}',
          style: theme.textTheme.labelSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
