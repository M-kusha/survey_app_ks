import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/appointment_deadline_picker.dart';
import 'package:echomeet/appointments/create/appointment_draft_route.dart';
import 'package:echomeet/appointments/create/step4_create_appointment.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/widgets/appointment_time_text.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class Step3CreateAppointment extends StatefulWidget {
  const Step3CreateAppointment({super.key});

  @override
  State<Step3CreateAppointment> createState() => Step3CreateAppointmentState();
}

class Step3CreateAppointmentState extends State<Step3CreateAppointment> {
  final _service = AppointmentService();

  Appointment? _appointment;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appointment != null) return;

    final draft = appointmentDraftOf(context);
    if (draft == null) {
      restartAppointmentWizard(context);
      return;
    }

    _appointment = draft;
    final appointment = draft;
    if (appointment.availableTimeSlots.isNotEmpty &&
        !isValidAppointmentDeadline(
          now: DateTime.now(),
          expirationAt: appointment.expirationAt,
          slotStarts: appointment.availableTimeSlots.map(
            (slot) => slot.startAt,
          ),
        )) {
      appointment.expirationDate = defaultAppointmentDeadline(
        now: DateTime.now(),
        earliestStartAt: _latestSensible,
      );
    }
  }

  DateTime get _latestSensible {
    final slots = _appointment!.availableTimeSlots;
    if (slots.isEmpty) return DateTime.now().add(const Duration(days: 365));
    return slots
        .map((slot) => slot.startAt)
        .reduce((left, right) => left.isBefore(right) ? left : right);
  }

  Future<void> _pickDate() async {
    final appointment = _appointment!;
    final picked = await pickAppointmentDeadline(
      context: context,
      initial: appointment.expirationAt,
      earliestStartAt: _latestSensible,
      zoneId: appointment.zoneId,
    );
    if (picked == null) return;
    setState(() => appointment.expirationDate = picked);
  }

  void _setDaysFromNow(int days) {
    final now = canonicalAppointmentInstant(DateTime.now());
    final latest = _latestSensible;
    final target = now.add(Duration(days: days));
    final chosen = target.isBefore(latest)
        ? target
        : latest.subtract(const Duration(milliseconds: 1));
    if (chosen.isAfter(now)) {
      setState(() => _appointment!.expirationDate = chosen);
    }
  }

  Future<void> _create() async {
    if (_saving) return;

    final appointment = _appointment!;
    if (!appointment.isValid()) {
      UIUtils.showSnackBar(context, 'please_fill_all_fields'.tr());
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.createAppointment(appointment);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              Step4CreateAppointment(appointment: appointment),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appointment = _appointment;
    // One frame between discovering the draft is missing and the wizard
    // restarting. Nothing to draw, and nothing to crash on.
    if (appointment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return WizardScaffold(
      step: 3,
      totalSteps: 3,
      appBarTitle: 'create_appointment'.tr(),
      title: 'create_appointment_step3_title'.tr(),
      subtitle: 'create_appointment_step3_subhead'.tr(),
      primaryLabel: 'create_appointment'.tr(),
      busy: _saving,
      onPrimary: _create,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DeadlineCard(
            date: appointment.expirationAt,
            zoneId: appointment.zoneId,
            onTap: _pickDate,
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            children: [
              for (final days in [2, 3, 7])
                ActionChip(
                  label: Text('in_days'.tr(namedArgs: {'count': '$days'})),
                  onPressed: () => _setDaysFromNow(days),
                ),
            ],
          ),
          const SizedBox(height: Spacing.xxl),
          Text('review'.tr(), style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          _ReviewCard(appointment: appointment),
        ],
      ),
    );
  }
}

class _DeadlineCard extends StatelessWidget {
  const _DeadlineCard({
    required this.date,
    required this.zoneId,
    required this.onTap,
  });

  final DateTime date;
  final String zoneId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContentCard(
      onTap: onTap,
      accent: scheme.primary,
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.md),
              color: scheme.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              Icons.how_to_vote_rounded,
              size: 20,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'voting_closes'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                AppointmentTimeText(
                  startAt: date,
                  zoneId: zoneId,
                  style: theme.textTheme.titleSmall,
                  secondaryStyle: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.edit_calendar_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(appointment.title, style: theme.textTheme.titleMedium),
          if (appointment.description.isNotEmpty) ...[
            const SizedBox(height: Spacing.xs),
            Text(
              appointment.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: Spacing.md),
          Text(
            'proposed_times'.tr(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final slot in appointment.availableTimeSlots)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(Radii.sm),
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.55,
                    ),
                  ),
                  child: AppointmentTimeText(
                    startAt: slot.startAt,
                    endAt: slot.endAt,
                    zoneId: appointment.zoneId,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
