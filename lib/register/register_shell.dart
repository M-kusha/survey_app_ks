import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/auth_shell.dart';
import 'package:echomeet/core/widgets/glass_panel.dart';
import 'package:flutter/material.dart';

class RegisterShell extends StatelessWidget {
  const RegisterShell({
    super.key,
    required this.step,
    required this.titleKey,
    required this.subtitleKey,
    required this.child,
    required this.continueLabelKey,
    required this.onContinue,
    this.busy = false,
    this.footer,
  });

  final int step;

  final String titleKey;
  final String subtitleKey;

  final Widget child;

  final String continueLabelKey;

  final VoidCallback? onContinue;

  final bool busy;

  final Widget? footer;

  static const totalSteps = 4;

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      onBack: Navigator.of(context).canPop()
          ? () => Navigator.of(context).maybePop()
          : null,
      aboveHeadline: StepProgress(step: step, total: totalSteps),
      headline: AuthHeadline(title: titleKey, subtitle: subtitleKey),
      form: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPanel(
            padding: const EdgeInsets.all(Spacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                child,
                const SizedBox(height: Spacing.lg),
                GlowButton(
                  onPressed: onContinue,
                  busy: busy,
                  label: continueLabelKey.tr(),
                ),
              ],
            ),
          ),
          if (footer case final footer?) ...[
            const SizedBox(height: Spacing.lg),
            footer,
          ],
        ],
      ),
    );
  }
}

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      label: 'step_of'.tr(namedArgs: {'current': '$step', 'total': '$total'}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 6),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    height: 4,

                    width: i == step
                        ? 32
                        : i < step
                        ? 20
                        : 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i <= step
                          ? scheme.primary
                          : scheme.onSurfaceVariant.withValues(alpha: 0.25),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Spacing.sm),
          ExcludeSemantics(
            child: Text(
              'step_of'.tr(namedArgs: {'current': '$step', 'total': '$total'}),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
