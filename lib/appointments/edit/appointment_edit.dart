import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/edit/step1_edit_appointments.dart';
import 'package:echomeet/appointments/edit/step2_edit_appointments.dart';
import 'package:echomeet/appointments/edit/step3_edit_appointments.dart';
import 'package:echomeet/appointments/edit/step4_edit_appointments.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentEditPage extends StatefulWidget {
  final Appointment appointment;
  final TimeSlot timeSlot;
  final String userName;

  const AppointmentEditPage({
    super.key,
    required this.appointment,
    required this.userName,
    required this.timeSlot,
  });

  @override
  AppointmentEditPageState createState() => AppointmentEditPageState();
}

class AppointmentEditPageState extends State<AppointmentEditPage> {
  late PageController _pageController;
  late List<Widget> _pages;
  int _currentPageIndex = 0;
  get _appointmentService => AppointmentService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = [
      AppointmentEditPageStep1(
        appointment: widget.appointment,
        onPageChange: _handlePageChange,
      ),
      AppointmentEditPageStep2(
        appointment: widget.appointment,
        onPageChange: _handlePageChange,
      ),
      AppointmentEditPageStep3(
        appointment: widget.appointment,
        onPageChange: _handlePageChange,
      ),
      AppointmentEditPageStep4(
        appointment: widget.appointment,
        onPageChange: _handlePageChange,
        timeSlot: widget.timeSlot,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          ' ${'appointment_edit'.tr()} ${widget.appointment.title}',
          style: TextStyle(
            fontSize: timeFontSize * 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView(
        controller: _pageController,
        children: _pages,
        onPageChanged: (int index) {
          setState(() {
            _currentPageIndex = index;
          });
        },
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _handleNextButtonPressed,
        buttonText: _currentPageIndex == _pages.length - 1
            ? 'update_appointment'.tr()
            : 'next'.tr(),
      ),
    );
  }

  Future<void> _handleNextButtonPressed() async {
    if (_currentPageIndex == _pages.length - 1) {
      _saveAppointment();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomNavigation(initialIndex: 1),
        ),
        (route) => false,
      );
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() {
        _currentPageIndex++;
      });
    }
  }

  void _saveAppointment() async {
    await _appointmentService.updateAppointment(widget.appointment);
  }

  void _handlePageChange(int index) {
    if (index > _currentPageIndex) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
    setState(() {
      _currentPageIndex = index;
    });
  }
}
