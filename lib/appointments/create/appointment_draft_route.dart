import 'package:echomeet/appointments/appointment_data.dart';
import 'package:flutter/material.dart';

/// The half-built appointment a wizard step was opened with, if there is one.
///
/// Steps two and three carry the draft in the route arguments. Both used to
/// cast it outright, which is a crash the moment a route is rebuilt without
/// them — a browser reload mid-wizard, a restored route, or any push that
/// forgot the argument. On web that produced a red screen and a dead page,
/// because the wizard's own state was gone and there was nothing to redraw.
Appointment? appointmentDraftOf(BuildContext context) =>
    ModalRoute.of(context)?.settings.arguments as Appointment?;

/// Sends the wizard back to its first step, after the current frame.
///
/// A draft that arrived empty cannot be recovered — the title, the times and
/// the description were only ever in memory. Starting over is the honest
/// outcome, and it beats a red screen. Navigation is scheduled rather than
/// immediate because a dependency change is not a legal time to navigate.
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
