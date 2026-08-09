import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/time_slot_editor.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class AppointmentEditPage extends StatefulWidget {
  const AppointmentEditPage({
    super.key,
    required this.appointment,
    required this.userName,
    required this.timeSlot,
  });

  final Appointment appointment;
  final String userName;
  final TimeSlot timeSlot;

  @override
  AppointmentEditPageState createState() => AppointmentEditPageState();
}

class AppointmentEditPageState extends State<AppointmentEditPage> {
  final _service = AppointmentService();
  final _formKey = GlobalKey<FormState>();

  late final _title = TextEditingController(text: widget.appointment.title);
  late final _description = TextEditingController(
    text: widget.appointment.description,
  );

  late List<TimeSlot> _slots = [...widget.appointment.availableTimeSlots];
  late DateTime _deadline = widget.appointment.expirationDate;

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  TimeSlot? get _confirmed =>
      _slots.where((slot) => slot.isConfirmed).firstOrNull;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(now) ? now : _deadline,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
      helpText: 'select_voting_expiration_date'.tr(),
    );
    if (picked == null) return;

    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  Future<void> _clearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('editing_confirmation_status_dialog_title'.tr()),
        content: Text('editing_confirmation_status_dialog_content'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() {
      _slots = [
        for (final slot in _slots)
          TimeSlot(
            start: slot.start,
            end: slot.end,
            expirationDate: slot.expirationDate,
          ),
      ];
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_slots.isEmpty) {
      UIUtils.showSnackBar(context, 'appointment_needs_a_time'.tr());
      return;
    }

    setState(() => _saving = true);

    final appointment = widget.appointment
      ..title = _title.text.trim()
      ..description = _description.text.trim()
      ..availableTimeSlots = _slots
      ..availableDates = _slots.map((slot) => slot.start).toList()
      ..confirmedTimeSlots = _slots.where((slot) => slot.isConfirmed).toList()
      ..expirationDate = _deadline;

    try {
      await _service.updateAppointment(appointment);
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'appointment_updated'.tr());
      Navigator.pop(context, true);
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
    final confirmed = _confirmed;

    return Scaffold(
      appBar: AppBar(title: Text('appointment_edit'.tr())),
      body: SafeArea(
        child: PageBody(
          maxWidth: 640,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (confirmed != null) ...[
                  _ConfirmedBanner(
                    slot: confirmed,
                    onClear: _clearConfirmation,
                  ),
                  const SizedBox(height: Spacing.lg),
                ],
                AppTextField(
                  label: 'create_appointment_title'.tr(),
                  controller: _title,
                  icon: Icons.title_rounded,
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'create_appointment_title_error'.tr()
                      : null,
                ),
                const SizedBox(height: Spacing.md),
                Text(
                  'create_appointment_description'.tr().toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
                TextFormField(
                  controller: _description,
                  maxLines: null,
                  minLines: 3,
                  maxLength: 1000,
                  keyboardType: TextInputType.multiline,
                  style: theme.textTheme.bodyLarge,
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'create_appointment_description_error'.tr()
                      : null,
                ),
                const SizedBox(height: Spacing.lg),
                Text('proposed_times'.tr(), style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.md),
                TimeSlotEditor(
                  slots: _slots,
                  onChanged: (slots) => setState(() => _slots = slots),
                ),
                const SizedBox(height: Spacing.xl),
                Text('voting_closes'.tr(), style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.md),
                _DeadlineRow(date: _deadline, onTap: _pickDeadline),
                const SizedBox(height: Spacing.xxl),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: WizardActionBar(
        child: FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('update_appointment'.tr()),
        ),
      ),
    );
  }
}

class _ConfirmedBanner extends StatelessWidget {
  const _ConfirmedBanner({required this.slot, required this.onClear});

  final TimeSlot slot;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    return ContentCard(
      accent: app.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusPill(
                label: 'time_slot_confirmed'.tr(),
                tone: StatusTone.positive,
                icon: Icons.event_available_rounded,
              ),
              const Spacer(),
              TextButton(onPressed: onClear, child: Text('reopen_voting'.tr())),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            '${DateFormat.yMMMMEEEEd().format(slot.start)} · '
            '${DateFormat.jm().format(slot.start)}',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'editing_confirmation_status_tip'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  const _DeadlineRow({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPast = date.isBefore(DateTime.now());

    return ContentCard(
      onTap: onTap,
      accent: isPast ? scheme.error : scheme.primary,
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
                  DateFormat.yMMMMEEEEd().format(date),
                  style: theme.textTheme.titleSmall,
                ),
                if (isPast)
                  Text(
                    'deadline_closed'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
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
