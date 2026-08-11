import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.primary.withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 26, color: scheme.primary),
              ),
              const SizedBox(height: Spacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (body case final body?) ...[
                const SizedBox(height: Spacing.xs),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (action case final action?) ...[
                const SizedBox(height: Spacing.lg),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ContentCard extends StatelessWidget {
  const ContentCard({
    super.key,
    required this.child,
    this.onTap,
    this.accent,
    this.muted = false,
    this.padding = const EdgeInsets.all(Spacing.md),
    this.progress,
  });

  final Widget child;
  final VoidCallback? onTap;

  final double? progress;

  final Color? accent;

  final bool muted;

  final EdgeInsetsGeometry padding;

  static const _inset = 18.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);

    return Material(
      // Previously `surfaceContainerLowest` when muted, which in light mode is
      // pure white — so an expired card was the brightest thing on the page,
      // exactly backwards. The two tones now come from one place.
      color: muted ? scheme.mutedCardSurface : scheme.cardSurface,
      // A muted card sits flat on the page; a live one is lifted off it.
      elevation: muted ? 0 : scheme.cardElevation,
      shadowColor: scheme.shadow.withValues(alpha: 0.18),
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(
                alpha: muted ? 0.4 : 0.75,
              ),
            ),
          ),

          child: Stack(
            children: [
              Padding(padding: padding, child: child),

              if (accent case final accent?)
                Positioned(
                  left: 0,
                  top: _inset,
                  bottom: _inset,
                  width: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              if (progress case final progress?)
                Positioned(
                  left: _inset,
                  right: _inset,
                  bottom: 0,
                  height: 2,
                  child: _ProgressRule(
                    value: progress,
                    color: accent ?? scheme.primary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRule extends StatelessWidget {
  const _ProgressRule({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(2);

    return LayoutBuilder(
      builder: (context, constraints) => DecoratedBox(
        // The track. Without it only the filled part was drawn, so a card 10%
        // of the way through its window showed a short coloured stub floating
        // at the bottom left with nothing behind it to say what it measured -
        // which reads as a rendering artefact, not as progress.
        decoration: BoxDecoration(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
          borderRadius: radius,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: constraints.maxWidth * value.clamp(0.0, 1.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.25), color],
              ),
              borderRadius: radius,
            ),
          ),
        ),
      ),
    );
  }
}

/// One column of cards on a narrow window, two on a wide one.
///
/// A single column capped at reading width leaves most of a desktop window
/// empty, which is what made the lists look sparse. Cards vary in height, so
/// the two columns are packed independently and items alternate between them,
/// rather than being laid out in rows: a row-based grid stretches every card to
/// the tallest in its row and puts the empty space straight back.
class CardColumns extends StatelessWidget {
  const CardColumns({
    super.key,
    required this.children,
    this.spacing = Spacing.md,
  });

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    Widget stack(List<Widget> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: EdgeInsets.only(bottom: spacing),
            child: item,
          ),
      ],
    );

    // A lone card keeps its column rather than stretching across both, so a
    // one-item section lines up with the sections above and below it.
    if (!context.canShowTwoPanes) return stack(children);

    final left = <Widget>[];
    final right = <Widget>[];
    for (final (index, child) in children.indexed) {
      (index.isEven ? left : right).add(child);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: stack(left)),
        SizedBox(width: spacing),
        Expanded(child: stack(right)),
      ],
    );
  }
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;

  final String? subtitle;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(height: 1.1),
              ),
              if (subtitle case final subtitle?) ...[
                const SizedBox(height: Spacing.xs),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 6,
                      width: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

class SearchPill extends StatelessWidget {
  const SearchPill({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.full),
          color: scheme.surfaceContainerHigh.withValues(alpha: 0.55),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: TextField(
                controller: controller,
                style: theme.textTheme.bodyMedium,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),

                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (value.text.isNotEmpty)
              InkResponse(
                onTap: controller.clear,
                radius: 16,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel({super.key, required this.label, this.count});

  final String label;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: Spacing.lg, bottom: Spacing.sm),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (count case final count?) ...[
            const SizedBox(width: Spacing.sm),
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Container(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateFab extends StatelessWidget {
  const CreateFab({
    super.key,
    required this.label,
    required this.onPressed,
    required this.heroTag,
  });

  final String label;
  final VoidCallback onPressed;
  final Object heroTag;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return FloatingActionButton(
        heroTag: heroTag,
        onPressed: onPressed,
        tooltip: label,
        child: const Icon(Icons.add_rounded),
      );
    }

    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      tooltip: label,
      icon: const Icon(Icons.add_rounded),
      label: Text(label),
    );
  }
}

class MetaChip extends StatelessWidget {
  const MetaChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }
}

class CircleAction extends StatelessWidget {
  const CircleAction({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: active
            ? scheme.primary.withValues(alpha: 0.14)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(
              icon,
              size: 19,
              color: active ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
