import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/step4_participate_appointment.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';

class ParticipantOverviewPage extends StatefulWidget {
  final Appointment appointment;
  final bool isAdmin;

  const ParticipantOverviewPage({
    super.key,
    required this.appointment,
    required this.isAdmin,
  });

  @override
  ParticipantOverviewPageState createState() => ParticipantOverviewPageState();
}

class ParticipantOverviewPageState extends State<ParticipantOverviewPage>
    with SingleTickerProviderStateMixin {
  final AppointmentService _appointmentService = AppointmentService();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize =
        Provider.of<FontSizeProvider>(context, listen: false).fontSize;
    final confirmedTimeSlots = Provider.of<List<TimeSlot>>(context);

    return Scaffold(
      body: ListView.builder(
        itemCount: widget.appointment.availableTimeSlots.length,
        itemBuilder: (context, index) {
          final timeSlot = widget.appointment.availableTimeSlots[index];
          final date = widget.appointment.availableDates.length > index
              ? widget.appointment.availableDates[index]
              : DateTime.now();
          final isConfirmed = confirmedTimeSlots.any((cts) =>
              cts.start == timeSlot.start &&
              cts.end == timeSlot.end &&
              cts.isConfirmed);

          return buildTimeSlotCard(
            context,
            fontSize,
            timeSlot,
            date,
            isConfirmed,
          );
        },
      ),
    );
  }

  Widget buildTimeSlotCard(
    BuildContext context,
    double fontSize,
    TimeSlot timeSlot,
    DateTime date,
    bool isConfirmed,
  ) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shadowColor: getButtonColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: isConfirmed
            ? BorderSide(color: getButtonColor(context), width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: () {
          navigateToTimeSlotParticipantsPage(context, timeSlot);
        },
        title: buildTitle(date, fontSize),
        subtitle: buildSubtitle(timeSlot, fontSize),
        trailing: buildParticipantsCount(context, fontSize),
        leading: buildLeadingIcon(context, isConfirmed),
      ),
    );
  }

  Widget buildTitle(DateTime date, double fontSize) {
    return Text(
      DateFormat('EEEE, MMMM d yyyy').format(date),
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
    );
  }

  Widget buildSubtitle(TimeSlot timeSlot, double fontSize) {
    return Text(
      '${DateFormat.jm().format(timeSlot.start)} - ${DateFormat.jm().format(timeSlot.end)}',
      style: TextStyle(
          fontSize: fontSize * 1.0,
          fontWeight: FontWeight.bold,
          color: Colors.grey),
    );
  }

  Widget buildParticipantsCount(BuildContext context, double fontSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getButtonColor(context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: getButtonColor(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.appointment.participationCount.toString(),
            style: TextStyle(
              fontSize: fontSize * 0.9,
              fontWeight: FontWeight.bold,
              color: getButtonColor(context),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.people,
            size: fontSize * 1.0,
            color: getButtonColor(context),
          ),
        ],
      ),
    );
  }

  Widget buildLeadingIcon(BuildContext context, bool isConfirmed) {
    return CircleAvatar(
      backgroundColor: getButtonColor(context),
      child: Icon(
        isConfirmed ? Icons.alarm_on_outlined : Icons.alarm,
      ),
    );
  }

  void navigateToTimeSlotParticipantsPage(
      BuildContext context, TimeSlot timeSlot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StreamProvider<List<TimeSlot>>.value(
          initialData: const [],
          value: _appointmentService
              .streamConfirmedTimeSlots(widget.appointment.appointmentId),
          child: TimeSlotParticipantsPage(
              appointment: widget.appointment,
              timeSlot: timeSlot,
              isAdmin: widget.isAdmin),
        ),
      ),
    );
  }
}
