import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/participants_appointments_button.dart';
import 'package:echomeet/appointments/participants/step1_participate_appointment.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentListItem extends StatelessWidget {
  final Appointment appointment;
  final bool hasUserParticipated;
  final bool isAdmin;
  final bool isAnyTimeSLotConfirmed;
  final AppointmentService appointmentService = AppointmentService();

  AppointmentListItem({
    Key? key,
    required this.appointment,
    required this.hasUserParticipated,
    required this.isAdmin,
    required this.isAnyTimeSLotConfirmed,
  }) : super(key: key);

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.grey[900];
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final timeFontSize = screenWidth < 600
        ? fontSize.clamp(0.0, 15.0)
        : fontSize.clamp(0.0, 30.0);
    final isExpired = appointment.expirationDate.isBefore(DateTime.now());
    final count = appointment.participationCount;

    return _listItems(
        context, isExpired, hasUserParticipated, timeFontSize, count);
  }

  GestureDetector _listItems(BuildContext context, bool isExpired,
      bool participated, double timeFontSize, int count) {
    return GestureDetector(
      onTap: (!isExpired)
          ? () => navigateToCorrectPage(context, participated, isAdmin)
          : null,
      child: Opacity(
        opacity: (isExpired || participated) ? 0.8 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child:
              _buildCard(context, timeFontSize, isExpired, count, participated),
        ),
      ),
    );
  }

  Card _buildCard(BuildContext context, double timeFontSize, bool isExpired,
      int count, bool participated) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isExpired
              ? getButtonColor(context).withOpacity(0.5)
              : getButtonColor(context),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Stack(
          children: [
            Column(
              children: [
                Text(
                  appointment.title,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? _textColor(context)
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: timeFontSize,
                  ),
                ),
                const SizedBox(height: 8.0),
                _buildInfoRow(context, timeFontSize, count, isExpired,
                    participated, isAnyTimeSLotConfirmed),
              ],
            ),
          ],
        ),
      ),
    );
  }

  RichText _buildRichText(BuildContext context, double timeFontSize,
      bool isExpired, bool hasParticipated, bool isAnyTimeSLotConfirmed) {
    String statusText;
    Color statusColor;

    if (isExpired) {
      statusText = 'expired'.tr();
      statusColor = Colors.red;
    } else if (isAnyTimeSLotConfirmed) {
      statusText = 'time_slot_confirmed'.tr();
      statusColor = getButtonColor(context);
    } else if (hasParticipated) {
      statusText = 'already_participated'.tr();
      statusColor = getButtonColor(context);
    } else {
      statusText = 'open'.tr();
      statusColor = getButtonColor(context);
    }
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '${'appointment_status_'.tr()}: ',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.light
                  ? _textColor(context)
                  : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: timeFontSize,
            ),
          ),
          TextSpan(
            text: statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: timeFontSize,
            ),
          ),
        ],
      ),
    );
  }

  Row _buildInfoRow(BuildContext context, double timeFontSize, int count,
      bool isExpired, bool hasUserParticipated, bool isAnyTimeSLotConfirmed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildColumnLeft(context, timeFontSize, isExpired, hasUserParticipated,
            isAnyTimeSLotConfirmed),
        _buildColumnRight(context, timeFontSize, count),
      ],
    );
  }

  Column _buildColumnLeft(BuildContext context, double timeFontSize,
      bool isExpired, bool hasUserParticipated, bool isAnyTimeSLotConfirmed) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildRichText(context, timeFontSize, isExpired, hasUserParticipated,
            isAnyTimeSLotConfirmed),
        SizedBox(height: timeFontSize),
        Text(
            '${'expires'.tr()} ${DateFormat("dd E y").format(appointment.expirationDate)}',
            style: TextStyle(
              fontSize: timeFontSize,
              fontWeight: FontWeight.bold,
            )),
      ],
    );
  }

  Column _buildColumnRight(
      BuildContext context, double timeFontSize, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'ID: ${appointment.appointmentId}',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.light
                ? _textColor(context)
                : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: timeFontSize,
          ),
        ),
        SizedBox(height: timeFontSize),
        Text(
          '${'participants'.tr()}: $count',
          style: TextStyle(
            fontSize: timeFontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void navigateToCorrectPage(
      BuildContext context, bool participated, bool isAdmin) {
    final isTimeSlotConfirmed =
        appointment.availableTimeSlots.any((ts) => ts.isConfirmed);

    if (participated || isTimeSlotConfirmed) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserSelectCategories(
            appointment: appointment,
            userName: '',
            timeSlot: TimeSlot(
              start: DateTime.now(),
              end: DateTime.now(),
              expirationDate: DateTime.now(),
            ),
            isAdmin: isAdmin,
            hasParticipated: participated,
            isAnyTimeSLotConfirmed: isTimeSlotConfirmed,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AppointmentNamePage(
            appointment: appointment,
            participant: AppointmentParticipants(
              userId: '',
              userName: '',
              status: '',
              participated: false,
              date: DateTime.now(),
              timeSlot: TimeSlot(
                start: DateTime.now(),
                end: DateTime.now(),
                expirationDate: DateTime.now(),
              ),
              profileImageUrl: '',
            ),
            hasParticipated: hasUserParticipated,
            isAdmin: isAdmin,
            isTimeSlotConfirmed: isTimeSlotConfirmed,
          ),
        ),
      );
    }
  }
}
