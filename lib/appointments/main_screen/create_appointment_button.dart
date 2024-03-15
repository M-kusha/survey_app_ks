import 'package:flutter/material.dart';
import 'package:survey_app_ks/utilities/colors.dart';

Widget buildCreateAppointmentButton(BuildContext context) {
  return FloatingActionButton(
    backgroundColor: ThemeBasedAppColors.getColor(
        context, 'buttonColor'), // Saturated color for light theme
    onPressed: () =>
        Navigator.of(context).pushNamed('/create_appointment_step_1'),
    tooltip: 'Add Appointment',
    child: Icon(
      Icons.add,
      color: ThemeBasedAppColors.getColor(context, 'textColor'),
    ),
  );
}
