import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

Color voteColor(BuildContext context, VoteStatus status) {
  final app = context.appColors;
  return switch (status) {
    VoteStatus.yes => app.success,
    VoteStatus.maybe => app.warning,
    VoteStatus.no => Theme.of(context).colorScheme.error,
  };
}

IconData voteIcon(VoteStatus status) => switch (status) {
  VoteStatus.yes => Icons.check_rounded,
  VoteStatus.maybe => Icons.question_mark_rounded,
  VoteStatus.no => Icons.close_rounded,
};

String voteLabelKey(VoteStatus status) => switch (status) {
  VoteStatus.yes => 'will_participate',
  VoteStatus.maybe => 'maybe_participate',
  VoteStatus.no => 'will_not_participate',
};

class VoteSlotCard extends StatelessWidget {
  const VoteSlotCard({
    super.key,
    required this.slot,
    required this.tally,
    required this.myStatus,
    required this.isLeader,
    required this.isTied,
    required this.enabled,
    required this.onChoose,
    required this.onShowVoters,
    this.onConfirm,
  });

  final TimeSlot slot;
  final SlotTally? tally;
  final VoteStatus? myStatus;

  final bool isLeader;
  final bool isTied;

  final bool enabled;
  final ValueChanged<VoteStatus> onChoose;
  final VoidCallback onShowVoters;

  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;
    final counts = tally;

    return ContentCard(
      accent: slot.isConfirmed
          ? app.success
          : isLeader
          ? scheme.primary
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: slot.start, confirmed: slot.isConfirmed),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat.MMMMEEEEd().format(slot.start),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DateFormat.jm().format(slot.start)} – '
                      '${DateFormat.jm().format(slot.end)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (isLeader) ...[
                      const SizedBox(height: Spacing.sm),
                      _LeaderBadge(isTied: isTied),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (counts != null && counts.responses > 0) ...[
            const SizedBox(height: Spacing.md),
            _TallyBar(tally: counts, onTap: onShowVoters),
          ],
          const SizedBox(height: Spacing.md),
          _VoteButtons(
            selected: myStatus,
            enabled: enabled,
            onChoose: onChoose,
          ),
          if (onConfirm case final onConfirm?) ...[
            const SizedBox(height: Spacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.event_available_rounded, size: 16),
                label: Text('confirm_this_time'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoteButtons extends StatelessWidget {
  const _VoteButtons({
    required this.selected,
    required this.enabled,
    required this.onChoose,
  });

  final VoteStatus? selected;
  final bool enabled;
  final ValueChanged<VoteStatus> onChoose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final status in VoteStatus.values) ...[
          if (status != VoteStatus.values.first)
            const SizedBox(width: Spacing.sm),
          Expanded(
            child: _VoteButton(
              status: status,
              selected: selected == status,
              enabled: enabled,
              onTap: () => onChoose(status),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoteButton extends StatelessWidget {
  const _VoteButton({
    required this.status,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final VoteStatus status;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = voteColor(context, status);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: voteLabelKey(status).tr(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.md),
          color: selected
              ? color.withValues(alpha: 0.16)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Column(
                children: [
                  Icon(
                    voteIcon(status),
                    size: 16,
                    color: selected
                        ? color
                        : enabled
                        ? scheme.onSurfaceVariant
                        : scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    voteLabelKey(status).tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: selected ? color : scheme.onSurfaceVariant,
                      letterSpacing: 0,
                    ),
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

class _TallyBar extends StatelessWidget {
  const _TallyBar({required this.tally, required this.onTap});

  final SlotTally tally;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    final segments = [
      (tally.yes, app.success),
      (tally.maybe, app.warning),
      (tally.no, theme.colorScheme.error),
    ].where((segment) => segment.$1 > 0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 6,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (count, color) in segments)
                      Expanded(
                        flex: count,
                        child: ColoredBox(color: color),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                for (final status in VoteStatus.values) ...[
                  Icon(
                    voteIcon(status),
                    size: 12,
                    color: voteColor(context, status),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${switch (status) {
                      VoteStatus.yes => tally.yes,
                      VoteStatus.maybe => tally.maybe,
                      VoteStatus.no => tally.no,
                    }}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: Spacing.md),
                ],
                const Spacer(),
                Text(
                  'see_who'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderBadge extends StatelessWidget {
  const _LeaderBadge({required this.isTied});

  final bool isTied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.full),
        color: scheme.primary.withValues(alpha: 0.14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up_rounded, size: 12, color: scheme.primary),
          const SizedBox(width: 4),
          Text(
            (isTied ? 'leading_tied' : 'leading').tr(),
            style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
          ),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.confirmed});

  final DateTime date;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;
    final tint = confirmed ? app.success : theme.colorScheme.primary;

    return Container(
      height: 48,
      width: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        color: tint.withValues(alpha: 0.12),
        border: Border.all(color: tint.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            DateFormat.MMM().format(date).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tint,
              fontSize: 9,
            ),
          ),
          Text(
            DateFormat.d().format(date),
            style: theme.textTheme.titleMedium?.copyWith(
              color: tint,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
