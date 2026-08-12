import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

class CreationSuccessPage extends StatelessWidget {
  const CreationSuccessPage({
    super.key,
    required this.title,
    required this.name,
    required this.facts,
    required this.onDone,
    this.doneLabel,
  });

  final String title;

  final String name;

  final List<({IconData icon, String label})> facts;

  final VoidCallback onDone;
  final String? doneLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false),
      body: SafeArea(
        child: PageBody(
          maxWidth: 480,
          centerVertically: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: app.success.withValues(alpha: 0.14),
                    border: Border.all(
                      color: app.success.withValues(alpha: 0.45),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: app.success,
                  ),
                ),
              ),
              const SizedBox(height: Spacing.xl),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                name,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (facts.isNotEmpty) ...[
                const SizedBox(height: Spacing.xl),
                ContentCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.lg,
                    vertical: Spacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final fact in facts)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: Spacing.xs,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                fact.icon,
                                size: 16,
                                color: scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: Spacing.md),
                              Expanded(
                                child: Text(
                                  fact.label,
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: Spacing.xl),
              Center(
                child: FilledButton(
                  onPressed: onDone,
                  child: Text(doneLabel ?? 'finish'.tr()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
