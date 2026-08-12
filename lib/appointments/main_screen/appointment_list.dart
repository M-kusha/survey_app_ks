import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/appointment_vote_page.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/time/deadline.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentListItem extends StatelessWidget {
  const AppointmentListItem({
    super.key,
    required this.appointment,
    required this.hasUserParticipated,
    required this.isAdmin,
    required this.isAnyTimeSLotConfirmed,
    this.now,
    this.onChanged,
  });

  final VoidCallback? onChanged;

  final Appointment appointment;
  final bool hasUserParticipated;
  final bool isAdmin;
  final bool isAnyTimeSLotConfirmed;

  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    context.watch<DeviceTimeZone?>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    final deadline = deadlineFor(
      appointment.expirationDate,
      now: now ?? DateTime.now(),
      openedAt: appointment.creationDate,
    );

    final (statusKey, tone, icon, accent) = switch (this) {
      _ when deadline.isPassed => (
        'expired',
        StatusTone.neutral,
        Icons.lock_outline_rounded,
        scheme.outline,
      ),
      _ when isAnyTimeSLotConfirmed => (
        'time_slot_confirmed',
        StatusTone.positive,
        Icons.event_available_rounded,
        app.success,
      ),
      _ when hasUserParticipated => (
        'already_participated',
        StatusTone.info,
        Icons.how_to_vote_rounded,
        app.info,
      ),
      _ when deadline.urgency == DeadlineUrgency.imminent => (
        deadline.labelKey,
        StatusTone.caution,
        Icons.bolt_rounded,
        app.warning,
      ),
      _ => (
        'open_status',
        StatusTone.caution,
        Icons.hourglass_bottom_rounded,
        scheme.primary,
      ),
    };

    return ContentCard(
      onTap: () => _open(context),
      muted: deadline.isPassed,
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DateBlock(date: appointment.expirationDate, tint: accent),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (appointment.description.trim().isNotEmpty) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(
                        appointment.description,
                        style: theme.textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: Spacing.sm),
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusPill(
                          label: statusKey.tr(
                            namedArgs: {'count': '${deadline.days}'},
                          ),
                          tone: tone,
                          icon: icon,
                        ),
                        MetaChip(
                          icon: Icons.group_outlined,
                          label: 'participants_count'.tr(
                            namedArgs: {
                              'count': '${appointment.participationCount}',
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: Spacing.sm),
                _AdminMenu(appointment: appointment, onChanged: onChanged),
              ],
            ],
          ),

          if (appointment.availableTimeSlots.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            _SlotStrip(
              slots: appointment.availableTimeSlots,
              zoneId: appointment.zoneId,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AppointmentVotePage(appointment: appointment, isAdmin: isAdmin),
      ),
    );

    onChanged?.call();
  }
}

class _DateBlock extends StatelessWidget {
  const _DateBlock({required this.date, required this.tint});

  final DateTime date;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 44,
      width: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        color: tint.withValues(alpha: 0.12),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
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

class _SlotStrip extends StatelessWidget {
  const _SlotStrip({required this.slots, required this.zoneId});

  final List<TimeSlot> slots;
  final String zoneId;

  static const _maxShown = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ordered = [
      ...slots.where((slot) => slot.isConfirmed),
      ...slots.where((slot) => !slot.isConfirmed),
    ];
    final shown = ordered.take(_maxShown).toList();
    final hidden = ordered.length - shown.length;

    final locale =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ?? 'en';
    final viewerZone = context.watch<DeviceTimeZone?>()?.zoneId;

    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final slot in shown)
          _SlotChip(
            slot: slot,
            zoneId: viewerZone,
            locale: locale,
            confirmed: slot.isConfirmed,
          ),
        if (hidden > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.sm),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Text(
              'more_slots'.tr(namedArgs: {'count': '$hidden'}),
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.zoneId,
    required this.locale,
    required this.confirmed,
  });

  final TimeSlot slot;

  final String? zoneId;
  final String locale;
  final bool confirmed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;
    final tint = confirmed ? app.success : scheme.onSurfaceVariant;

    final start = zoneId == null
        ? slot.startAt.toLocal()
        : appointmentTimeInZone(slot.startAt, zoneId!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.sm),
        color: confirmed
            ? app.success.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(
          color: confirmed
              ? app.success.withValues(alpha: 0.45)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (confirmed) ...[
                Icon(Icons.check_rounded, size: 11, color: app.success),
                const SizedBox(width: 3),
              ],
              Text(
                DateFormat.MMMEd(locale).format(start).toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tint,
                  fontSize: 9,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            DateFormat.jm(locale).format(start),
            style: theme.textTheme.labelLarge?.copyWith(
              color: confirmed ? app.success : scheme.onSurface,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminMenu extends StatelessWidget {
  const _AdminMenu({required this.appointment, required this.onChanged});

  final Appointment appointment;
  final VoidCallback? onChanged;

  Future<void> _delete(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_appointment'.tr()),

        content: Text(
          'delete_appointment_confirm'.tr(
            namedArgs: {
              'name': appointment.title,
              'count': '${appointment.participationCount}',
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await AppointmentService().deleteAppointment(appointment.appointmentId);
      messenger.showSnackBar(
        SnackBar(content: Text('appointment_deleted'.tr())),
      );
      onChanged?.call();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<void Function()>(
      tooltip: 'manage'.tr(),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: () => _delete(context),
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
              const SizedBox(width: Spacing.md),
              Text(
                'delete_appointment'.tr(),
                style: TextStyle(color: scheme.error),
              ),
            ],
          ),
        ),
      ],
      child: CircleAction(
        icon: Icons.more_horiz_rounded,
        tooltip: 'manage'.tr(),
        onTap: null,
      ),
    );
  }
}
