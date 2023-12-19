import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/appointment/user_survey/user_survey_step_4.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class ParticipantOverviewPage extends StatelessWidget {
  final Survey survey;

  const ParticipantOverviewPage({Key? key, required this.survey})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      body: ListView.builder(
        itemCount: survey.availableTimeSlots.length,
        itemBuilder: (context, index) {
          final timeSlot = survey.availableTimeSlots[index];
          final dayOfWeek =
              DateFormat.EEEE().format(survey.availableDates[index]);
          final dayOfMonth =
              DateFormat.d().format(survey.availableDates[index]);
          final monthOfYear =
              DateFormat.MMMM().format(survey.availableDates[index]);
          final totalCount = survey.participants
              .where((participant) =>
                  participant.timeSlot.start == timeSlot.start &&
                  participant.timeSlot.end == timeSlot.end)
              .length;
          final timeFormat = DateFormat.jm();
          final startTimeString = timeFormat.format(timeSlot.start);
          final endTimeString = timeFormat.format(timeSlot.end);
          final isConfirmed = survey.confirmedTimeSlots.contains(timeSlot);

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TimeSlotParticipantsPage(
                      survey: survey, timeSlot: timeSlot),
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
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: timeFontSize * 2.3,
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
