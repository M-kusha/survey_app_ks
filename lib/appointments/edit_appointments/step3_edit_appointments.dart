import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class AppointmentEditPageStep3 extends StatefulWidget {
  final Appointment appointment;
  final Function(int) onPageChange;
  const AppointmentEditPageStep3(
      {required this.appointment, super.key, required this.onPageChange});

  @override
  State<AppointmentEditPageStep3> createState() =>
      AppointmentEditPageStep3State();
}

class AppointmentEditPageStep3State extends State<AppointmentEditPageStep3> {
  late Appointment appointment;
  DateTime _expirationDate = DateTime.now(); // add expiration date variable

  @override
  void initState() {
    super.initState();
    appointment = widget.appointment;
    _expirationDate = appointment.expirationDate;
  }

  // function to show date picker
  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _expirationDate) {
      setState(() {
        _expirationDate = pickedDate;
        appointment.expirationDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16.0),
          Text(
            'select_voting_expiration_date'.tr(),
            style: TextStyle(
              fontSize: timeFontSize,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).brightness == Brightness.light
                  ? const Color(0xff004B96)
                  : Colors.white,
            ),
          ),
          const SizedBox(height: 16.0),
          Text(DateFormat("d MMMM y").format(_expirationDate),
              style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xff004B96)
                    : Colors.white,
              )),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16.0),
                buildAddDatesButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAddDatesButton() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return IconButton(
      onPressed: () {
        setState(() {});
        _selectExpirationDate(context);
      },
      icon: Icon(Icons.edit_calendar,
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xff004B96)
              : Colors.white),
      iconSize: timeFontSize * 1.5,
    );
  }
}
