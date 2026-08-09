import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/step4_create_appointment.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
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
    _appointment ??= ModalRoute.of(context)!.settings.arguments as Appointment;
  }

  DateTime get _latestSensible {
    final slots = _appointment!.availableTimeSlots;
    if (slots.isEmpty) return DateTime.now().add(const Duration(days: 365));
    return slots.map((s) => s.start).reduce((a, b) => a.isBefore(b) ? a : b);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final latest = _latestSensible;

    final picked = await showDatePicker(
      context: context,
      initialDate: _appointment!.expirationDate.isAfter(latest)
          ? latest
          : _appointment!.expirationDate,
      firstDate: now,
      lastDate: latest.isAfter(now) ? latest : now,
      helpText: 'select_voting_expiration_date'.tr(),
    );
    if (picked == null) return;

    setState(() {
      _appointment!.expirationDate = DateTime(
        picked.year,
        picked.month,
        picked.day,
        23,
        59,
      );
    });
  }

  void _setDaysFromNow(int days) {
    final target = DateTime.now().add(Duration(days: days));
    final latest = _latestSensible;

    setState(() {
      final chosen = target.isAfter(latest) ? latest : target;
      _appointment!.expirationDate = DateTime(
        chosen.year,
        chosen.month,
        chosen.day,
        23,
        59,
      );
    });
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
    } on StateError {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'no_company_error'.tr());
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
    final appointment = _appointment!;

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
          _DeadlineCard(date: appointment.expirationDate, onTap: _pickDate),
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
  const _DeadlineCard({required this.date, required this.onTap});

  final DateTime date;
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
                Text(
                  DateFormat.yMMMMEEEEd().format(date),
                  style: theme.textTheme.titleSmall,
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
                  child: Text(
                    '${DateFormat.MMMEd().format(slot.start)} · '
                    '${DateFormat.jm().format(slot.start)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
