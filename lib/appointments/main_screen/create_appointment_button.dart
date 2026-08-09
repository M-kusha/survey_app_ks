import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:flutter/material.dart';

Widget buildCreateAppointmentButton(BuildContext context) {
  return CreateFab(
    label: 'add_appointments'.tr(),
    onPressed: () =>
        Navigator.of(context).pushNamed('/create_appointment_step_1'),
  );
}
