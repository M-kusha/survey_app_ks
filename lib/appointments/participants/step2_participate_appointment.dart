import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class AppontmentParticipate extends StatefulWidget {
  final Appointment appointment;
  final String userName;

  const AppontmentParticipate({
    Key? key,
    required this.appointment,
    required this.userName,
  }) : super(key: key);

  @override
  AppontmentParticipateState createState() => AppontmentParticipateState();
}

class AppontmentParticipateState extends State<AppontmentParticipate> {
  String? userId = FirebaseAuth.instance.currentUser?.uid;
  final AppointmentService _appointmentService = AppointmentService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      body: ListView.builder(
        itemCount: widget.appointment.availableDates.length,
        itemBuilder: (context, dateIndex) {
          final date = widget.appointment.availableDates[dateIndex];
          final timeSlot = widget.appointment.availableTimeSlots[dateIndex];
          final dayOfWeek = DateFormat.EEEE().format(date);
          final dayOfMonth = DateFormat.d().format(date);
          final monthOfYear = DateFormat.MMMM().format(date);
          final timeFormat = DateFormat.jm();
          final startTimeString = timeFormat.format(timeSlot.start);
          final endTimeString = timeFormat.format(timeSlot.end);

          return ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$dayOfWeek $dayOfMonth $monthOfYear',
                        style: TextStyle(fontSize: timeFontSize)),
                    Text('$startTimeString - $endTimeString',
                        style: TextStyle(fontSize: timeFontSize)),
                  ],
                ),
                Container(
                  alignment: Alignment.center,
                  width: MediaQuery.of(context).size.width < 600
                      ? timeFontSize * 9
                      : timeFontSize * 13,
                  height: MediaQuery.of(context).size.width < 600
                      ? timeFontSize * 2
                      : timeFontSize * 2.3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20.0),
                    color: Colors.grey[200],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      buildIconButton(
                          Icons.check_circle_outline_outlined,
                          widget.appointment.participants.any((p) =>
                                  p.userName == widget.userName &&
                                  p.date == date &&
                                  p.timeSlot == timeSlot &&
                                  p.status == 'joined')
                              ? Colors.green
                              : Colors.grey, () {
                        setState(() {
                          updateParticipantStatus(
                              widget.userName, date, timeSlot, 'joined');
                        });
                      }, 'will_participate'.tr()),
                      buildIconButton(
                          Icons.help_outline_outlined,
                          widget.appointment.participants.any((p) =>
                                  p.userName == widget.userName &&
                                  p.date == date &&
                                  p.timeSlot == timeSlot &&
                                  p.status == 'maybe')
                              ? Colors.blue
                              : Colors.grey, () {
                        setState(() {
                          updateParticipantStatus(
                              widget.userName, date, timeSlot, 'maybe');
                        });
                      }, 'maybe_participate'.tr()),
                      buildIconButton(
                          Icons.cancel_outlined,
                          widget.appointment.participants.any((p) =>
                                  p.userName == widget.userName &&
                                  p.date == date &&
                                  p.timeSlot == timeSlot &&
                                  p.status == 'declined')
                              ? Colors.red
                              : Colors.grey, () {
                        setState(() {
                          updateParticipantStatus(
                              widget.userName, date, timeSlot, 'declined');
                        });
                      }, 'will_not_participate'.tr()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget buildIconButton(
    IconData icon,
    Color color,
    VoidCallback onTap,
    String tooltipMessage,
  ) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Tooltip(
      message: tooltipMessage,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(16.0),
        border: Border.all(
          color: Theme.of(context).primaryColor,
          width: 2.0,
        ),
      ),
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: timeFontSize,
        fontWeight: FontWeight.bold,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.0),
        child: InkWell(
          onTap: onTap,
          child: Icon(
            icon,
            color: color,
            size: timeFontSize * 1.8,
          ),
        ),
      ),
    );
  }

  void updateParticipantStatus(
      String userName, DateTime date, TimeSlot timeSlot, String status) async {
    if (userId == null) {
      return;
    }

    final hasParticipated = widget.appointment.participants.any((p) =>
        p.userId == userId &&
        p.date == date &&
        p.timeSlot.start == timeSlot.start &&
        p.timeSlot.end == timeSlot.end);

    if (!hasParticipated) {
      setState(() {
        widget.appointment.participants.removeWhere((p) =>
            p.userName == userName && p.date == date && p.timeSlot == timeSlot);
        widget.appointment.participants.add(AppointmentParticipants(
            userName: userName,
            date: date,
            timeSlot: timeSlot,
            status: status,
            userId: userId!,
            participated: true));
        widget.appointment.participationCount++;
      });

      _appointmentService.updateParticipantStatus(userId!,
          widget.appointment.appointmentId, userName, date, timeSlot, status);
    }
  }
}
