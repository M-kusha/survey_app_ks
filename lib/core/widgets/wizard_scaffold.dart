import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/register/register_shell.dart' show StepProgress;
import 'package:flutter/material.dart';

class WizardScaffold extends StatelessWidget {
  const WizardScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.subtitle,
    this.appBarTitle,
    this.busy = false,
    this.secondary,
    this.maxWidth = 640,
  });

  final int step;
  final int totalSteps;

  final String title;
  final String? subtitle;

  final String? appBarTitle;

  final Widget child;

  final String primaryLabel;

  final VoidCallback? onPrimary;

  final bool busy;

  final Widget? secondary;

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle ?? title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: Spacing.lg),
            child: Center(
              child: Text(
                'step_of'.tr(
                  namedArgs: {'current': '$step', 'total': '$totalSteps'},
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          maxWidth: maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepProgress(step: step, total: totalSteps),
              const SizedBox(height: Spacing.lg),
              Text(title, style: theme.textTheme.headlineSmall),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: Spacing.xl),
              child,
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: WizardActionBar(
        maxWidth: maxWidth,
        secondary: secondary,
        child: FilledButton(
          onPressed: busy ? null : onPrimary,
          child: busy
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(primaryLabel),
        ),
      ),
    );
  }
}

class WizardActionBar extends StatelessWidget {
  const WizardActionBar({
    super.key,
    required this.child,
    this.secondary,
    this.maxWidth = 640,
  });

  final Widget child;
  final Widget? secondary;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final compact = context.isCompact;
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: compact
            ? null
            : Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            Spacing.lg,
            Spacing.md,
            Spacing.lg,
            Spacing.lg,
          ),

          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (secondary case final secondary?) ...[
                    secondary,
                    const SizedBox(width: Spacing.md),
                  ],
                  if (compact)
                    Expanded(child: child)
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 168),
                      child: child,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
