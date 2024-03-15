import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/appointments/participants/step4_participate_appointment.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class ParticipantOverviewPage extends StatelessWidget {
  final Appointment appointment;

  const ParticipantOverviewPage({Key? key, required this.appointment})
      : super(key: key);

  get _appointmentService => AppointmentService();

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final confirmedTimeSlots = Provider.of<List<TimeSlot>>(context);
    final participants = appointment.participationCount;

    return Scaffold(
      body: ListView.builder(
        itemCount: appointment.availableTimeSlots.length,
        itemBuilder: (context, index) {
          final timeSlot = appointment.availableTimeSlots[index];
          final date = appointment.availableDates.length > index
              ? appointment.availableDates[index]
              : DateTime.now();
          final dayOfWeek = DateFormat.EEEE().format(date);
          final dayOfMonth = DateFormat.d().format(date);
          final monthOfYear = DateFormat.MMMM().format(date);

          final totalCount = participants;

          final isConfirmed = confirmedTimeSlots.any((cts) =>
              cts.start == timeSlot.start &&
              cts.end == timeSlot.end &&
              cts.isConfirmed);

          final timeFormat = DateFormat.jm();
          final startTimeString = timeFormat.format(timeSlot.start);
          final endTimeString = timeFormat.format(timeSlot.end);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StreamProvider<List<TimeSlot>>.value(
                    initialData: const [],
                    value: _appointmentService
                        .streamConfirmedTimeSlots(appointment.appointmentId),
                    child: TimeSlotParticipantsPage(
                        appointment: appointment, timeSlot: timeSlot),
                  ),
                ),
              );
            },
            child: Column(
              children: [
                ListTile(
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.group),
                          Text('$totalCount',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: timeFontSize)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$dayOfWeek $dayOfMonth $monthOfYear',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: timeFontSize),
                          ),
                          Text('$startTimeString - $endTimeString',
                              style: TextStyle(fontSize: timeFontSize)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          isConfirmed
                              ? Icon(
                                  Icons.check_circle_outline_outlined,
                                  color: ThemeBasedAppColors.getColor(
                                      context, 'buttonColor'),
                                  size: timeFontSize * 2.0,
                                )
                              : const Icon(
                                  null,
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: fontSize * 0.5,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
