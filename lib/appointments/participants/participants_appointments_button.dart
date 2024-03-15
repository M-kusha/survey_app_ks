import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/edit_appointments/appointment_edit.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/appointments/participants/step2_participate_appointment.dart';
import 'package:survey_app_ks/appointments/participants/step3_participate_appointment.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class UserSelectCategories extends StatefulWidget {
  final Appointment appointment;
  final TimeSlot timeSlot;
  final String userName;
  const UserSelectCategories(
      {super.key,
      required this.appointment,
      required this.userName,
      required this.timeSlot});

  @override
  UserSelectCategoriesState createState() => UserSelectCategoriesState();
}

class UserSelectCategoriesState extends State<UserSelectCategories> {
  bool participateSelected = true;
  bool overviewSelected = false;
  bool _isAdmin = false;
  Appointment? numberOfParticipants;
  late AppointmentService appointmentService;
  bool _userHasParticipated = false;
  bool _isLoading = true;

  bool _isTimeSlotConfirmed = false;

  @override
  void initState() {
    super.initState();
    appointmentService = AppointmentService();
    _checkParticipationAndAdminStatus();
  }

  void _checkParticipationAndAdminStatus() async {
    final isAdmin = await appointmentService.fetchAdminStatus();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    bool userHasParticipated = false;
    bool isTimeSlotConfirmed = await appointmentService
        .isAnyTimeSlotConfirmed(widget.appointment.appointmentId);

    if (userId != null) {
      userHasParticipated = await appointmentService.hasCurrentUserParticipated(
          widget.appointment.appointmentId, userId);
    }

    setState(() {
      _isAdmin = isAdmin;
      _userHasParticipated = userHasParticipated;
      _isTimeSlotConfirmed = isTimeSlotConfirmed;

      overviewSelected = userHasParticipated || _isTimeSlotConfirmed;
      participateSelected = !(userHasParticipated || _isTimeSlotConfirmed);
      _isLoading = false;
    });
  }

  void _navigateToHomePage() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final isButtonDisabled = _userHasParticipated || _isTimeSlotConfirmed;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Loading...', style: TextStyle(fontSize: timeFontSize)),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(widget.appointment.title,
                style: TextStyle(fontSize: timeFontSize)),
            const SizedBox(width: 8),
          ],
        ),
        centerTitle: true,
        actions: [
          if (_isAdmin) buildEditButton(),
        ],
        leading: _userHasParticipated
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _navigateToHomePage,
              )
            : Navigator.canPop(context)
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  left: 25.0,
                  right: 25.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        if (!isButtonDisabled) {
                          setState(() {
                            participateSelected = true;
                            overviewSelected = false;
                          });
                        }
                      },
                      style: ButtonStyle(
                        overlayColor: MaterialStateColor.resolveWith(
                          (states) => isButtonDisabled
                              ? Colors
                                  .transparent // set to transparent to disable ripple effect
                              : Colors.grey.withOpacity(
                                  0.1), // set overlay color for normal state
                        ),
                      ),
                      child: Text(
                        'participate'.tr(),
                        style: TextStyle(
                          color:
                              participateSelected ? Colors.green : Colors.grey,
                          fontSize: timeFontSize,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          participateSelected = false;
                          overviewSelected = true;
                        });
                      },
                      style: ButtonStyle(
                        overlayColor: MaterialStateColor.resolveWith(
                          (states) => isButtonDisabled
                              ? Colors
                                  .transparent // set to transparent to disable ripple effect
                              : Colors.grey.withOpacity(
                                  0.1), // set overlay color for normal state
                        ),
                      ),
                      child: Text(
                        'overview'.tr(),
                        style: TextStyle(
                          color: overviewSelected ? Colors.green : Colors.grey,
                          fontSize: timeFontSize,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 2,
                      color: participateSelected ? Colors.green : Colors.grey,
                    ),
                  ),
                  Expanded(
                    flex: 0,
                    child: Container(
                      height: 2,
                      color: Colors.black,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 2,
                      color: overviewSelected ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
          if (participateSelected)
            Positioned(
              top: 70.0,
              left: 0.0,
              right: 0.0,
              bottom: 100.0,
              child: AppontmentParticipate(
                appointment: widget.appointment,
                userName: widget.userName,
              ),
            ),
          if (overviewSelected)
            Positioned(
              top: 70.0,
              left: 0.0,
              right: 0.0,
              bottom: 100.0,
              child: MultiProvider(
                providers: [
                  StreamProvider<List<TimeSlot>>.value(
                    value: appointmentService.streamConfirmedTimeSlots(
                        widget.appointment.appointmentId),
                    initialData: const [],
                  ),
                ],
                child: ParticipantOverviewPage(appointment: widget.appointment),
              ),
            ),
          if (participateSelected)
            Positioned(
              bottom: 0.0,
              left: 0.0,
              right: 0.0,
              child: buildParticipateButton(context),
            ),
        ],
      ),
    );
  }

  Widget buildParticipateButton(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(timeFontSize * 4.0),
              padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
            ),
            onPressed: () async {
              appointmentService
                  .updateParticipationCount(widget.appointment.appointmentId);
              setState(() {
                overviewSelected = true;
                participateSelected = false;
                _userHasParticipated = true;
              });
            },
            child: Text('next'.tr(), style: TextStyle(fontSize: timeFontSize)),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget buildEditButton() {
    return IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AppointmentEditPage(
              appointment: widget.appointment,
              userName: '',
              timeSlot: widget.timeSlot,
            ),
          ),
        );
      },
    );
  }
}
