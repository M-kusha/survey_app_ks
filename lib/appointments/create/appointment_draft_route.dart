import 'package:echomeet/appointments/appointment_data.dart';
import 'package:flutter/material.dart';

Appointment? appointmentDraftOf(BuildContext context) =>
    ModalRoute.of(context)?.settings.arguments as Appointment?;

void restartAppointmentWizard(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/create_appointment_step_1',
      (route) => route.isFirst,
    );
  });
}
