import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';

Widget buildCreateAppointmentButton(BuildContext context) {
  return FloatingActionButton(
    backgroundColor: getButtonColor(context),
    onPressed: () =>
        Navigator.of(context).pushNamed('/create_appointment_step_1'),
    tooltip: 'add_appointments'.tr(),
    child: Icon(Icons.add, color: getTextColor(context)),
  );
}
