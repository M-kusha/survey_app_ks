import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/widgets/appointment_time_dialogs.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class TimeSlotEditor extends StatelessWidget {
  const TimeSlotEditor({
    super.key,
    required this.slots,
    required this.zoneId,
    required this.onChanged,
  });

  final List<TimeSlot> slots;
  final String zoneId;
  final ValueChanged<List<TimeSlot>> onChanged;

  Future<void> _add(BuildContext context) async {
    final slot = await _editSlot(context, null, zoneId);
    if (slot == null) return;
    onChanged([...slots, slot]..sort((a, b) => a.start.compareTo(b.start)));
  }

  Future<void> _edit(BuildContext context, int index) async {
    final slot = await _editSlot(context, slots[index], zoneId);
    if (slot == null) return;

    final next = [...slots];
    next[index] = slot;
    onChanged(next..sort((a, b) => a.start.compareTo(b.start)));
  }

  void _remove(int index) {
    onChanged([...slots]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (slots.isEmpty)
          _EmptySlots(onAdd: () => _add(context))
        else ...[
          for (var i = 0; i < slots.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: _SlotRow(
                slot: slots[i],
                zoneId: zoneId,
                onTap: () => _edit(context, i),
                onRemove: () => _remove(i),
              ),
            ),
          const SizedBox(height: Spacing.sm),
          OutlinedButton.icon(
            onPressed: () => _add(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('add_time_slot'.tr()),
          ),
        ],
        const SizedBox(height: Spacing.sm),
        Text(
          'time_slot_hint'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({
    required this.slot,
    required this.zoneId,
    required this.onTap,
    required this.onRemove,
  });

  final TimeSlot slot;
  final String zoneId;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    final start = appointmentTimeInZone(slot.startAt, zoneId);
    final end = appointmentTimeInZone(slot.endAt, zoneId);
    final isPast = slot.startAt.isBefore(DateTime.now());

    return ContentCard(
      onTap: onTap,
      accent: isPast ? scheme.error : scheme.primary,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.E().format(start).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.primary,
                    fontSize: 9,
                  ),
                ),
                Text(
                  DateFormat.d().format(start),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.primary,
                    height: 1,
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
                Text(
                  DateFormat.MMMMEEEEd().format(start),
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${DateFormat.jm().format(start)} – '
                      '${DateFormat.jm().format(end)} · $zoneId',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      _durationLabel(slot),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: app.info,
                      ),
                    ),
                  ],
                ),
                if (isPast) ...[
                  const SizedBox(height: Spacing.xs),
                  StatusPill(
                    label: 'slot_in_the_past'.tr(),
                    tone: StatusTone.danger,
                    icon: Icons.history_rounded,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'delete'.tr(),
            icon: Icon(
              Icons.close_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  static String _durationLabel(TimeSlot slot) {
    final minutes = slot.endAt.difference(slot.startAt).inMinutes;
    if (minutes <= 0) return '';
    if (minutes < 60) {
      return 'duration_minutes'.tr(namedArgs: {'m': '$minutes'});
    }

    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0
        ? 'duration_hours'.tr(namedArgs: {'h': '$hours'})
        : 'duration_hours_minutes'.tr(namedArgs: {'h': '$hours', 'm': '$rest'});
  }
}

class _EmptySlots extends StatelessWidget {
  const _EmptySlots({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Spacing.xxl),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),

          color: scheme.primary.withValues(alpha: 0.05),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Icon(Icons.more_time_rounded, color: scheme.primary),
            const SizedBox(height: Spacing.sm),
            Text('add_time_slot'.tr(), style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

Future<TimeSlot?> _editSlot(
  BuildContext context,
  TimeSlot? existing,
  String zoneId,
) async {
  final now = DateTime.now();
  final initial = appointmentTimeInZone(
    existing?.startAt ?? now.add(const Duration(days: 1)),
    zoneId,
  );
  final nowInZone = appointmentTimeInZone(now, zoneId);

  final day = await showDatePicker(
    context: context,
    initialDate: existing == null && initial.isBefore(nowInZone)
        ? nowInZone
        : initial,
    firstDate: DateTime(nowInZone.year, nowInZone.month, nowInZone.day),
    lastDate: nowInZone.add(const Duration(days: 365 * 2)),
  );
  if (day == null || !context.mounted) return null;

  final start = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
    helpText: 'pick_start_time'.tr(),
  );
  if (start == null || !context.mounted) return null;

  final wallTime = DateTime.utc(
    day.year,
    day.month,
    day.day,
    start.hour,
    start.minute,
  );
  final resolution = resolveAppointmentWallTime(
    zoneId: zoneId,
    wallTime: wallTime,
  );
  if (resolution.isNonexistent) {
    await showNonexistentAppointmentTime(context);
    return null;
  }
  final startsAt = resolution.isAmbiguous
      ? await chooseRepeatedAppointmentTime(
          context,
          resolution.instants,
          zoneId,
        )
      : resolution.single;
  if (startsAt == null || !context.mounted) return null;

  final minutes = await showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (context) => _DurationSheet(
      selected: existing == null
          ? 60
          : existing.end.difference(existing.start).inMinutes,
    ),
  );
  if (minutes == null) return null;

  final endsAt = startsAt.add(Duration(minutes: minutes));

  return TimeSlot(
    slotId: appointmentSlotIdAfterEdit(
      existing: existing,
      startAt: startsAt,
      endAt: endsAt,
    ),
    start: startsAt,
    end: endsAt,
    isConfirmed: existing?.isConfirmed ?? false,
  );
}

@visibleForTesting
String appointmentSlotIdAfterEdit({
  required TimeSlot? existing,
  required DateTime startAt,
  required DateTime endAt,
  String Function()? idFactory,
}) {
  if (existing != null &&
      existing.startAt == canonicalAppointmentInstant(startAt) &&
      existing.endAt == canonicalAppointmentInstant(endAt)) {
    return existing.slotId;
  }
  return (idFactory ?? const Uuid().v4)();
}

class _DurationSheet extends StatelessWidget {
  const _DurationSheet({required this.selected});

  final int selected;

  static const _options = [15, 30, 45, 60, 90, 120, 180];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.xl,
          0,
          Spacing.xl,
          Spacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('how_long'.tr(), style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.lg),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                for (final minutes in _options)
                  ChoiceChip(
                    label: Text(
                      minutes < 60
                          ? 'duration_minutes'.tr(namedArgs: {'m': '$minutes'})
                          : minutes % 60 == 0
                          ? 'duration_hours'.tr(
                              namedArgs: {'h': '${minutes ~/ 60}'},
                            )
                          : 'duration_hours_minutes'.tr(
                              namedArgs: {
                                'h': '${minutes ~/ 60}',
                                'm': '${minutes % 60}',
                              },
                            ),
                    ),
                    selected: minutes == selected,
                    onSelected: (_) => Navigator.pop(context, minutes),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
