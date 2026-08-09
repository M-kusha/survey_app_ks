import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
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

    _appointment ??= ModalRoute.of(context)!.settings.arguments as Appointment;
  }

  void _setSlots(List<TimeSlot> slots) {
    setState(() {
      final appointment = _appointment!;
      appointment.availableTimeSlots = slots;

      appointment.availableDates = slots.map((slot) => slot.start).toList();
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
    final appointment = _appointment!;
    final slots = appointment.availableTimeSlots;

    return WizardScaffold(
      step: 2,
      totalSteps: 3,
      appBarTitle: 'create_appointment'.tr(),
      title: 'create_appointment_step2_title'.tr(),
      subtitle: 'create_appointment_step2_subhead'.tr(),
      primaryLabel: 'next'.tr(),

      onPrimary:
          slots.isEmpty || slots.any((s) => s.start.isBefore(DateTime.now()))
          ? null
          : _next,
      child: TimeSlotEditor(slots: slots, onChanged: _setSlots),
    );
  }
}
