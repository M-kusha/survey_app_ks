import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter/material.dart';

Future<void> showNonexistentAppointmentTime(BuildContext context) =>
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('appointment_dst_gap_title'.tr()),
        content: Text('appointment_dst_gap_body'.tr()),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text('confirm'.tr()),
          ),
        ],
      ),
    );

Future<DateTime?> chooseRepeatedAppointmentTime(
  BuildContext context,
  List<DateTime> candidates,
  String zoneId,
) => showDialog<DateTime>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('appointment_dst_fold_title'.tr()),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('appointment_dst_fold_body'.tr()),
        const SizedBox(height: Spacing.md),
        for (var index = 0; index < candidates.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, candidates[index]),
              child: Text(
                '${index == 0 ? 'appointment_dst_first'.tr() : 'appointment_dst_second'.tr()} · '
                '${appointmentUtcOffset(candidates[index], zoneId)}',
              ),
            ),
          ),
      ],
    ),
  ),
);
