import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/appointments/participants/participants_appointments_button.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentNamePage extends StatefulWidget {
  final Appointment appointment;
  final AppointmentParticipants participant;
  final bool isAdmin;
  final bool hasParticipated;
  final bool isTimeSlotConfirmed;

  const AppointmentNamePage({
    super.key,
    required this.appointment,
    required this.participant,
    required this.isAdmin,
    required this.hasParticipated,
    required this.isTimeSlotConfirmed,
  });

  @override
  AppointmentNamePageState createState() => AppointmentNamePageState();
}

class AppointmentNamePageState extends State<AppointmentNamePage> {
  final AppointmentService _appointmentService = AppointmentService();
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  void _initPage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final userId = currentUser.uid;

      if (userId.isNotEmpty) {
        String name = await _appointmentService.fetchUserNameById(userId);
        setState(() {
          _userName = name;
        });
      }
    }
  }

  void _onNextPressed() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.participant.userName = _userName;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserSelectCategories(
            appointment: widget.appointment,
            userName: widget.participant.userName,
            timeSlot: widget.participant.timeSlot,
            isAdmin: widget.isAdmin,
            hasParticipated: widget.hasParticipated,
            isAnyTimeSLotConfirmed: widget.isTimeSlotConfirmed,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
          title: Text(
            widget.appointment.title,
            style: TextStyle(
              fontSize: timeFontSize * 1.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: getAppbarColor(context)),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(timeFontSize * 1.5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Card(
                elevation: 5,
                shadowColor: getButtonColor(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: EdgeInsets.all(timeFontSize),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height * 0.7,
                      minWidth: MediaQuery.of(context).size.width * 0.9,
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          SizedBox(height: timeFontSize * 2),
                          Text(
                            "${"hello".tr()} $_userName!\n${'welcome_to_this'.tr()}",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: timeFontSize + 4,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: timeFontSize * 2),
                          Text(
                            widget.appointment.description,
                            textAlign: TextAlign.justify,
                            style: TextStyle(
                              fontSize: timeFontSize + 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }
}
