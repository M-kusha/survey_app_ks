import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/appointment_draft_route.dart';
import 'package:echomeet/appointments/create/time_slot_editor.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:flutter/material.dart';

class Step2CreateAppointment extends StatefulWidget {
  const Step2CreateAppointment({super.key});

  @override
  Step2CreateAppointmentState createState() => Step2CreateAppointmentState();
}

class Step2CreateAppointmentState extends State<Step2CreateAppointment> {
  Appointment? _appointment;

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
  }

  void _setSlots(List<TimeSlot> slots) {
    setState(() {
      final appointment = _appointment!;
      appointment.availableTimeSlots = slots;
    });
  }

  void _next() {
    Navigator.pushNamed(
      context,
      '/create_appointment_step_3',
      arguments: _appointment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _appointment;
    // One frame between discovering the draft is missing and the wizard
    // restarting. Nothing to draw, and nothing to crash on.
    if (appointment == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final slots = appointment.availableTimeSlots;

    return WizardScaffold(
      step: 2,
      totalSteps: 3,
      appBarTitle: 'create_appointment'.tr(),
      title: 'create_appointment_step2_title'.tr(),
      subtitle: 'create_appointment_step2_subhead'.tr(),
      primaryLabel: 'next'.tr(),

      onPrimary:
          slots.isEmpty ||
              slots.any((slot) => !slot.startAt.isAfter(DateTime.now()))
          ? null
          : _next,
      child: TimeSlotEditor(
        slots: slots,
        zoneId: appointment.zoneId,
        onChanged: _setSlots,
      ),
    );
  }
}
