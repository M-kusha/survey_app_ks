import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/widgets/appointment_time_dialogs.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter/material.dart';

Future<DateTime?> pickAppointmentDeadline({
  required BuildContext context,
  required DateTime initial,
  required DateTime earliestStartAt,
  required String zoneId,
}) async {
  final now = DateTime.now();
  final safeInitial =
      isValidAppointmentDeadline(
        now: now,
        expirationAt: initial,
        slotStarts: [earliestStartAt],
      )
      ? initial
      : defaultAppointmentDeadline(now: now, earliestStartAt: earliestStartAt);
  final initialWall = appointmentTimeInZone(safeInitial, zoneId);
  final nowWall = appointmentTimeInZone(now, zoneId);
  final lastWall = appointmentTimeInZone(earliestStartAt, zoneId);

  final day = await showDatePicker(
    context: context,
    initialDate: initialWall,
    firstDate: DateTime(nowWall.year, nowWall.month, nowWall.day),
    lastDate: DateTime(lastWall.year, lastWall.month, lastWall.day),
    helpText: 'select_voting_expiration_date'.tr(),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initialWall),
    helpText: 'appointment_deadline_time'.tr(),
  );
  if (time == null || !context.mounted) return null;

  final resolution = resolveAppointmentWallTime(
    zoneId: zoneId,
    wallTime: DateTime.utc(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    ),
  );
  if (resolution.isNonexistent) {
    await showNonexistentAppointmentTime(context);
    return null;
  }

  final candidate = resolution.isAmbiguous
      ? await chooseRepeatedAppointmentTime(
          context,
          resolution.instants,
          zoneId,
        )
      : resolution.single;
  if (candidate == null || !context.mounted) return null;
  if (!isValidAppointmentDeadline(
    now: DateTime.now(),
    expirationAt: candidate,
    slotStarts: [earliestStartAt],
  )) {
    await _showMessage(
      context,
      'appointment_deadline_invalid_title'.tr(),
      'appointment_deadline_invalid_body'.tr(),
    );
    return null;
  }
  return candidate;
}

Future<void> _showMessage(BuildContext context, String title, String body) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );
