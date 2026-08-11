import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/appointment_deadline_picker.dart';
import 'package:echomeet/appointments/create/time_slot_editor.dart';
import 'package:echomeet/appointments/edit/appointment_edit_conflict.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/widgets/appointment_time_text.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/time/appointment_time.dart';
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

  late final TextEditingController _title;
  late final TextEditingController _description;
  late List<TimeSlot> _slots;
  late DateTime _deadline;

  bool _saving = false;
  bool _reopenVoting = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.appointment.title);
    _description = TextEditingController(text: widget.appointment.description);
    _slots = widget.appointment.availableTimeSlots.map(_copySlot).toList();
    _deadline = widget.appointment.expirationAt;
  }

  TimeSlot _copySlot(TimeSlot slot) => TimeSlot(
    slotId: slot.slotId,
    start: slot.startAt,
    end: slot.endAt,
    isConfirmed: slot.isConfirmed,
  );

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  TimeSlot? get _confirmed {
    if (_reopenVoting) return null;
    final confirmedId = widget.appointment.confirmedSlotId;
    if (confirmedId == null) return null;
    return widget.appointment.availableTimeSlots
        .where((slot) => slot.slotId == confirmedId)
        .firstOrNull;
  }

  String _originalSlotLabel(TimeSlot slot) {
    final startOffset = appointmentUtcOffset(
      slot.startAt,
      widget.appointment.zoneId,
    );
    final endOffset = appointmentUtcOffset(
      slot.endAt,
      widget.appointment.zoneId,
    );
    final range = formatAppointmentRange(
      startAt: slot.startAt,
      endAt: slot.endAt,
      zoneId: widget.appointment.zoneId,
      locale: context.locale.toLanguageTag(),
    );
    return '$range (${widget.appointment.zoneId}, $startOffset'
        '${startOffset == endOffset ? '' : ' → $endOffset'})';
  }

  Future<void> _pickDeadline() async {
    final earliest = _slots
        .map((slot) => slot.startAt)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    final picked = await pickAppointmentDeadline(
      context: context,
      initial: _deadline,
      earliestStartAt: earliest,
      zoneId: widget.appointment.zoneId,
    );
    if (picked == null) return;
    setState(() => _deadline = picked);
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
      _reopenVoting = true;
      _slots = [
        for (final slot in _slots)
          TimeSlot(slotId: slot.slotId, start: slot.startAt, end: slot.endAt),
      ];
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_slots.isEmpty) {
      UIUtils.showSnackBar(context, 'appointment_needs_a_time'.tr());
      return;
    }
    final confirmedId = widget.appointment.confirmedSlotId;
    if (!_reopenVoting &&
        confirmedId != null &&
        !_slots.any((slot) => slot.slotId == confirmedId)) {
      UIUtils.showSnackBar(context, 'appointment_edit_conflict'.tr());
      return;
    }

    final edited = Appointment(
      companyId: widget.appointment.companyId,
      createdBy: widget.appointment.createdBy,
      appointmentId: widget.appointment.appointmentId,
      title: _title.text.trim(),
      description: _description.text.trim(),
      zoneId: widget.appointment.zoneId,
      availableTimeSlots: _slots,
      expirationDate: _deadline,
      creationDate: widget.appointment.createdAt,
      revision: widget.appointment.revision,
      confirmedSlotId: _reopenVoting
          ? null
          : widget.appointment.confirmedSlotId,
      participantUserIds: widget.appointment.participantUserIds,
    );
    if (!edited.isValid()) {
      UIUtils.showSnackBar(context, 'appointment_deadline_invalid_body'.tr());
      return;
    }

    setState(() => _saving = true);

    try {
      await _service.updateAppointment(
        appointment: edited,
        reopenVoting: _reopenVoting,
      );
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'appointment_updated'.tr());
      Navigator.pop(context, true);
    } on AppointmentVotedSlotRemovalBlocked catch (error) {
      if (!mounted) return;
      final originalSlots = {
        for (final slot in widget.appointment.availableTimeSlots)
          slot.slotId: slot,
      };
      final blockedSlots = error.blockedSlotIds
          .map((slotId) => originalSlots[slotId])
          .toList();
      if (blockedSlots.any((slot) => slot == null)) {
        UIUtils.showSnackBar(context, 'error_occurred'.tr());
        return;
      }
      final labels = blockedSlots
          .cast<TimeSlot>()
          .map(_originalSlotLabel)
          .join('\n');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('appointment_voted_slots_blocked_title'.tr()),
          content: SingleChildScrollView(
            child: Text(
              'appointment_voted_slots_blocked_body'.tr(
                namedArgs: {'slots': labels},
              ),
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('ok'.tr()),
            ),
          ],
        ),
      );
    } on AppointmentEditConflict {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'appointment_edit_conflict'.tr());
    } on AppointmentEditMissing {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'appointment_deleted'.tr());
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
                    zoneId: widget.appointment.zoneId,
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
                  zoneId: widget.appointment.zoneId,
                  onChanged: (slots) => setState(() => _slots = slots),
                ),
                const SizedBox(height: Spacing.xl),
                Text('voting_closes'.tr(), style: theme.textTheme.titleMedium),
                const SizedBox(height: Spacing.md),
                _DeadlineRow(
                  date: _deadline,
                  zoneId: widget.appointment.zoneId,
                  onTap: _pickDeadline,
                ),
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
  const _ConfirmedBanner({
    required this.slot,
    required this.zoneId,
    required this.onClear,
  });

  final TimeSlot slot;
  final String zoneId;
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
          AppointmentTimeText(
            startAt: slot.startAt,
            endAt: slot.endAt,
            zoneId: zoneId,
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
  const _DeadlineRow({
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
    final isPast = !date.isAfter(DateTime.now());

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
                AppointmentTimeText(
                  startAt: date,
                  zoneId: zoneId,
                  style: theme.textTheme.titleSmall,
                  secondaryStyle: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
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
