import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/widgets/creation_success.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';

class Step4CreateAppointment extends StatelessWidget {
  const Step4CreateAppointment({super.key, required this.appointment});

  final Appointment appointment;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();

    return CreationSuccessPage(
      title: 'appointment_created_successfully'.tr(),
      name: appointment.title,
      facts: [
        (
          icon: Icons.schedule_rounded,
          label: 'time_slots_offered'.tr(
            namedArgs: {'count': '${appointment.availableTimeSlots.length}'},
          ),
        ),
        (
          icon: Icons.how_to_vote_rounded,
          label: 'voting_closes_on'.tr(
            namedArgs: {
              'date': DateFormat.yMMMEd(
                locale,
              ).add_jm().format(appointment.expirationDate),
            },
          ),
        ),
      ],
      onDone: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomNavigation(initialIndex: 1),
        ),
        (route) => false,
      ),
    );
  }
}
