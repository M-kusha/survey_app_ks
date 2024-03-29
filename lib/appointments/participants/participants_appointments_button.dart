import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/edit/appointment_edit.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/appointments/participants/step2_participate_appointment.dart';
import 'package:survey_app_ks/appointments/participants/step3_participate_appointment.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class UserSelectCategories extends StatefulWidget {
  final Appointment appointment;
  final TimeSlot timeSlot;
  final String userName;
  final bool isAdmin;
  final bool hasParticipated;
  final bool isAnyTimeSLotConfirmed;

  const UserSelectCategories({
    Key? key,
    required this.appointment,
    required this.userName,
    required this.timeSlot,
    required this.isAdmin,
    required this.hasParticipated,
    required this.isAnyTimeSLotConfirmed,
  }) : super(key: key);

  @override
  UserSelectCategoriesState createState() => UserSelectCategoriesState();
}

class UserSelectCategoriesState extends State<UserSelectCategories> {
  late AppointmentService appointmentService;
  bool participateSelected = true;
  bool overviewSelected = false;
  bool _isAdmin = false;
  bool _userHasParticipated = false;
  bool _isTimeSlotConfirmed = false;

  @override
  void initState() {
    super.initState();
    appointmentService = AppointmentService();
    _checkParticipationAndAdminStatus();
  }

  void _checkParticipationAndAdminStatus() async {
    final isAdmin = widget.isAdmin;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    bool userHasParticipated = false;
    bool isTimeSlotConfirmed = widget.isAnyTimeSLotConfirmed;

    if (userId != null) {
      userHasParticipated = widget.hasParticipated;
    }

    setState(() {
      _isAdmin = isAdmin;
      _userHasParticipated = userHasParticipated;
      _isTimeSlotConfirmed = isTimeSlotConfirmed;
      overviewSelected = userHasParticipated || _isTimeSlotConfirmed;
      participateSelected = !(userHasParticipated || _isTimeSlotConfirmed);
    });
  }

  @override
  Widget build(BuildContext context) {
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final fontSize = fontSizeProvider.fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final isButtonDisabled = _userHasParticipated || _isTimeSlotConfirmed;

    return Scaffold(
      appBar: _buildAppBar(context, timeFontSize),
      body: _buildBody(context, isButtonDisabled, timeFontSize),
      bottomNavigationBar: participateSelected
          ? buildBottomElevatedButton(
              context: context,
              onPressed: _onNextPressed,
              buttonText: 'next',
            )
          : const SizedBox.shrink(),
    );
  }

  AppBar _buildAppBar(BuildContext context, double fontSize) {
    bool canPop = Navigator.canPop(context);
    return AppBar(
      title: _buildTitle(fontSize),
      centerTitle: true,
      actions: _isAdmin ? [buildEditButton()] : [],
      leading: _userHasParticipated
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _navigateToHomePage)
          : canPop
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop())
              : null,
    );
  }

  Widget _buildTitle(double fontSize) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(widget.appointment.title,
            style: TextStyle(fontSize: fontSize * 1.5)),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBody(
      BuildContext context, bool isButtonDisabled, double fontSize) {
    return Stack(
      children: [
        Column(
          children: [
            _buildTabBar(context, isButtonDisabled, fontSize),
            _buildIndicator(),
            const SizedBox(height: 16),
          ],
        ),
        if (participateSelected) _buildParticipateView(),
        if (overviewSelected) _buildOverviewView(),
      ],
    );
  }

  Widget _buildTabBar(
      BuildContext context, bool isButtonDisabled, double fontSize) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTabButton(
            context: context,
            label: 'participate',
            isSelected: participateSelected,
            isButtonDisabled: isButtonDisabled,
            fontSize: fontSize,
            onTap: () => _onTabSelected(true, false),
          ),
          _buildTabButton(
            context: context,
            label: 'overview',
            isSelected: overviewSelected,
            isButtonDisabled: isButtonDisabled,
            fontSize: fontSize,
            onTap: () => _onTabSelected(false, true),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required BuildContext context,
    required String label,
    required bool isSelected,
    required bool isButtonDisabled,
    required double fontSize,
    required VoidCallback onTap,
  }) {
    return TextButton(
      onPressed: isButtonDisabled ? null : onTap,
      style: ButtonStyle(
        overlayColor: MaterialStateColor.resolveWith(
          (states) => isButtonDisabled
              ? Colors.transparent
              : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Text(
        label.tr(),
        style: TextStyle(
          color: isSelected ? getButtonColor(context) : Colors.grey,
          fontSize: fontSize * 1.2,
        ),
      ),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
            flex: 2,
            child: Container(
                height: 2,
                color: participateSelected
                    ? getButtonColor(context)
                    : Colors.grey)),
        Expanded(flex: 0, child: Container(height: 2, color: Colors.black)),
        Expanded(
            flex: 2,
            child: Container(
                height: 2,
                color:
                    overviewSelected ? getButtonColor(context) : Colors.grey)),
      ],
    );
  }

  Widget _buildParticipateView() {
    return Positioned(
      top: 70.0,
      left: 0.0,
      right: 0.0,
      bottom: 100.0,
      child: AppontmentParticipate(
        appointment: widget.appointment,
        userName: widget.userName,
      ),
    );
  }

  Widget _buildOverviewView() {
    return Positioned(
      top: 70.0,
      left: 0.0,
      right: 0.0,
      bottom: 100.0,
      child: MultiProvider(
        providers: [
          StreamProvider<List<TimeSlot>>.value(
            value: appointmentService
                .streamConfirmedTimeSlots(widget.appointment.appointmentId),
            initialData: const [],
          ),
        ],
        child: ParticipantOverviewPage(
          appointment: widget.appointment,
          isAdmin: widget.isAdmin,
        ),
      ),
    );
  }

  void _onTabSelected(bool participate, bool overview) {
    setState(() {
      participateSelected = participate;
      overviewSelected = overview;
    });
  }

  void _onNextPressed() async {
    appointmentService
        .updateParticipationCount(widget.appointment.appointmentId);
    setState(() {
      overviewSelected = true;
      participateSelected = false;
      _userHasParticipated = true;
      widget.appointment.participationCount += 1;
    });
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

  void _navigateToHomePage() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
