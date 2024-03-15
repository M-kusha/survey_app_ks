import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/appointments/participants/participants_appointments_button.dart';
import 'package:survey_app_ks/appointments/participants/step1_participate_appointment.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class AppintmentListItem extends StatelessWidget {
  final Appointment appointment;
  final bool hasUserParticipated;
  final AppointmentService appointmentService = AppointmentService();

  AppintmentListItem({
    Key? key,
    required this.appointment,
    required this.hasUserParticipated,
  }) : super(key: key);

  Color? _textColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? const Color(0xFF004B96)
        : Colors.grey[900];
  }

  @override
  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final screenWidth = MediaQuery.of(context).size.width;
    final timeFontSize = screenWidth < 600
        ? fontSize.clamp(00.0, 15.0)
        : fontSize.clamp(00.0, 30.0);
    final isExpired = appointment.expirationDate.isBefore(DateTime.now());

    return FutureBuilder<bool>(
      future: AppointmentService().hasCurrentUserParticipated(
          appointment.appointmentId, FirebaseAuth.instance.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                Text(
                  'Loading...'.tr(),
                  style: TextStyle(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }

        final participated = snapshot.data ?? false;
        final count = appointment.participationCount;
        final isTimeSlotConfirmed =
            appointment.availableTimeSlots.any((ts) => ts.isConfirmed);

        void navigateToCorrectPage() {
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
                    )),
              ),
            );
          }
        }

        return GestureDetector(
          onTap: isExpired ? null : navigateToCorrectPage,
          child: Opacity(
            opacity: isExpired ? 0.5 : 1.0,
            child: Container(
              padding: EdgeInsets.all(timeFontSize * 1.5),
              margin: EdgeInsets.symmetric(
                  vertical: timeFontSize, horizontal: timeFontSize * 1.5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.0),
                color: ThemeBasedAppColors.getColor(context, 'textColor'),
                boxShadow: [
                  if (Theme.of(context).brightness == Brightness.light)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      spreadRadius: 0,
                      blurRadius: 4,
                      offset: const Offset(0, 4),
                    )
                  else
                    BoxShadow(
                      color:
                          ThemeBasedAppColors.getColor(context, 'buttonColor')
                              .withOpacity(0.5),
                      spreadRadius: 1,
                      blurRadius: 2,
                      offset: const Offset(0, 0.1),
                    ),
                ],
              ),
              child: Stack(
                children: [
                  if (participated)
                    Positioned(
                      top: 0,
                      right: -1,
                      child: Icon(
                        Icons.check_circle_outline,
                        size: timeFontSize * 1.3,
                        color: ThemeBasedAppColors.getColor(
                            context, 'buttonColor'),
                      ),
                    ),
                  Column(
                    children: [
                      Column(
                        children: [
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${'appointment_status_'.tr()}: ',
                                  style: TextStyle(
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? _textColor(context)
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: timeFontSize,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      isExpired ? 'expired'.tr() : 'open'.tr(),
                                  style: TextStyle(
                                    color: isExpired
                                        ? Colors.red
                                        : ThemeBasedAppColors.getColor(
                                            context, 'buttonColor'),
                                    fontWeight: FontWeight.bold,
                                    fontSize: timeFontSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8.0),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    appointment.title,
                                    style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? _textColor(context)
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: timeFontSize,
                                    ),
                                  ),
                                  SizedBox(height: timeFontSize),
                                  Text(
                                      '${'voting_expiration_date'.tr()}: ${DateFormat("dd E y").format(appointment.expirationDate)}',
                                      style: TextStyle(
                                        fontSize: timeFontSize,
                                        fontWeight: FontWeight.bold,
                                      )),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'ID: ${appointment.appointmentId}',
                                    style: TextStyle(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
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
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget buildExpandedField(
    BuildContext context, bool isSearching, String searchQuery) {
  final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
  final timeFontSize = getTimeFontSize(context, fontSize);
  final appointmentService =
      Provider.of<AppointmentService>(context, listen: false);

  return FutureBuilder<String?>(
    future: appointmentService.getCompanyId(),
    builder: (context, snapshot) {
      if (!snapshot.hasData || snapshot.data == null) {
        return const Center(child: CircularProgressIndicator());
      }

      String companyId = snapshot.data!;

      return StreamBuilder<List<Appointment>>(
        stream: appointmentService.getAppointmentList(companyId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          List<Appointment> appointments = snapshot.data ?? [];
          final filteredAppointments = appointments
              .where((appointment) =>
                  appointment.title
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()) ||
                  appointment.appointmentId
                      .toLowerCase()
                      .contains(searchQuery.toLowerCase()))
              .toList();

          if (filteredAppointments.isEmpty && !isSearching) {
            return Expanded(
              child: Center(
                child: Text(
                  'no_surveys_added_yet'.tr(),
                  style: TextStyle(fontSize: timeFontSize * 1.2),
                ),
              ),
            );
          } else if (filteredAppointments.isEmpty && isSearching) {
            return Expanded(
              child: Center(
                child: Text(
                  'no_matching_surveys'.tr(),
                  style: TextStyle(fontSize: timeFontSize * 1.2),
                ),
              ),
            );
          }

          return Expanded(
            child: ListView.separated(
              separatorBuilder: (context, index) =>
                  const SizedBox(height: 20.0),
              itemCount: filteredAppointments.length,
              itemBuilder: (context, index) {
                return AppintmentListItem(
                  appointment: filteredAppointments[index],
                  hasUserParticipated: false,
                );
              },
            ),
          );
        },
      );
    },
  );
}
