import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ProductShowcase extends StatefulWidget {
  const ProductShowcase({super.key});

  @override
  State<ProductShowcase> createState() => _ProductShowcaseState();
}

class _ProductShowcaseState extends State<ProductShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || _animating) return;
    _animating = true;
    _float.repeat();
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : _designHeight;
          final gap = math.min((height - _cardExtent) / 2, _maxGap);
          final top = math.max((height - (gap * 2 + _cardExtent)) / 2, 0.0);

          final step = math.min(constraints.maxWidth * 0.14, 76.0);

          return AnimatedBuilder(
            animation: _float,
            builder: (context, _) {
              double y(int index) {
                final drift = _animating
                    ? math.sin((_float.value + index / 3) * 2 * math.pi) * 6
                    : 0.0;
                return top + gap * index + drift;
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: y(0),
                    child: const _Tilt(angle: -0.035, child: _SurveyCard()),
                  ),
                  Positioned(
                    left: step * 2,
                    top: y(1),
                    child: const _Tilt(angle: 0.028, child: _MeetingCard()),
                  ),
                  Positioned(
                    left: step,
                    top: y(2),
                    child: const _Tilt(angle: -0.018, child: _ResponsesCard()),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

const double _cardExtent = 104;

const double _maxGap = 190;

const double _designHeight = 440;

const int _score = 87;

final DateTime _firstSlot = DateTime(2025, 1, 7, 10);
final DateTime _secondSlot = DateTime(2025, 1, 8, 14);

String _slotLabel(DateTime at) => DateFormat.E().add_jm().format(at);

const Color _darkCardTop = Color(0xFF454F66);

class _Tilt extends StatelessWidget {
  const _Tilt({required this.angle, required this.child});

  final double angle;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Transform.rotate(angle: angle, child: child);
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.child, this.width = 250});

  final Widget child;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = scheme.brightness == Brightness.dark;

    return Container(
      width: width,
      padding: const EdgeInsets.all(Spacing.lg),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.lg),

        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [_darkCardTop, const Color(0xFF303A4D)]
              : [Colors.white, const Color(0xFFF4F6FB)],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : scheme.outlineVariant.withValues(alpha: 0.6),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.09),
            blurRadius: 34,
            spreadRadius: -6,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CardLabel extends StatelessWidget {
  const _CardLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _SurveyCard extends StatelessWidget {
  const _SurveyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    return _MiniCard(
      child: Row(
        children: [
          SizedBox(
            height: 52,
            width: 52,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _score / 100,
                  strokeWidth: 5,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(app.success),
                ),
                Text(
                  '$_score',
                  style: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLabel('showcase_survey_label'.tr()),
                const SizedBox(height: 4),
                Text(
                  'showcase_survey_title'.tr(),
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'showcase_survey_responses'.tr(),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    return _MiniCard(
      width: 230,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardLabel('showcase_meeting_label'.tr()),
          const SizedBox(height: 4),
          Text(
            'showcase_meeting_title'.tr(),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              _Slot(label: _slotLabel(_firstSlot), votes: 3, confirmed: false),
              const SizedBox(width: Spacing.sm),
              _Slot(
                label: _slotLabel(_secondSlot),
                votes: 7,
                confirmed: true,
                tint: app.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({
    required this.label,
    required this.votes,
    required this.confirmed,
    this.tint,
  });

  final String label;
  final int votes;
  final bool confirmed;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = tint ?? scheme.onSurfaceVariant;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.sm),

          color: confirmed
              ? accent.withValues(alpha: 0.14)
              : (scheme.brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black)
                    .withValues(alpha: 0.06),
          border: Border.all(
            color: confirmed
                ? accent.withValues(alpha: 0.55)
                : Colors.transparent,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'showcase_votes'.tr(namedArgs: {'count': '$votes'}),
              style: theme.textTheme.bodySmall?.copyWith(
                color: confirmed ? accent : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsesCard extends StatelessWidget {
  const _ResponsesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _MiniCard(
      width: 210,
      child: Row(
        children: [
          SizedBox(
            height: 32,
            width: 74,
            child: Stack(
              children: [
                for (var i = 0; i < 4; i++)
                  Positioned(
                    left: i * 17.0,
                    child: Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: [
                          scheme.primary,
                          scheme.tertiary,
                          scheme.secondary,
                          scheme.primaryContainer,
                        ][i],

                        border: Border.all(
                          color: scheme.brightness == Brightness.dark
                              ? _darkCardTop
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CardLabel('showcase_attending_label'.tr()),
                const SizedBox(height: 2),
                Text(
                  'showcase_attending_value'.tr(),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
