import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/bottom_navigation.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class Step4CreateAppointment extends StatefulWidget {
  final Appointment appointment;

  const Step4CreateAppointment({Key? key, required this.appointment})
      : super(key: key);

  @override
  State<Step4CreateAppointment> createState() => Step4CreateAppointmentState();
}

class Step4CreateAppointmentState extends State<Step4CreateAppointment> {
  void _onNextPressed() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const BottomNavigation(initialIndex: 1),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    double boxHeight = MediaQuery.of(context).size.width < 600
        ? timeFontSize * 1
        : timeFontSize * 1.5;

    double textFontSize = MediaQuery.of(context).size.width < 600
        ? timeFontSize * 1
        : timeFontSize * 1.5;
    Color textColor = Theme.of(context).brightness == Brightness.light
        ? const Color(0xff004B96)
        : Colors.white;

    double spacerHeight = MediaQuery.of(context).size.width < 600 ? 150 : 250;

    return Scaffold(
      appBar: AppBar(
        title: Text('create_appointment'.tr(),
            style: TextStyle(fontSize: timeFontSize * 1.5)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            child: Padding(
              padding: EdgeInsets.all(boxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'appointment_created_successfully'.tr(),
                    style: TextStyle(
                        fontSize: textFontSize + 2,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  SizedBox(height: boxHeight),
                  Text(
                    'your_id_information'.tr(),
                    style: TextStyle(
                        fontSize: textFontSize,
                        fontWeight: FontWeight.bold,
                        color: textColor),
                  ),
                  SizedBox(height: boxHeight),
                  Text(
                    'share_id_information'.tr(),
                    style: TextStyle(
                      fontSize: textFontSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: spacerHeight),
                ],
              ),
            ),
          ),
          SizedBox(height: boxHeight),
          SizedBox(
            child: GestureDetector(
              onTap: () {
                Clipboard.setData(
                    ClipboardData(text: widget.appointment.appointmentId));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                    'appointment_id_copied'.tr(),
                    style: TextStyle(
                      fontSize: textFontSize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ));
              },
              child: Align(
                alignment: Alignment.center, // Align text to the center
                child: Text(
                  '${'appointment_id'.tr()} ${widget.appointment.appointmentId}',
                  style: TextStyle(
                      fontSize: textFontSize,
                      fontWeight: FontWeight.bold,
                      color: textColor),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'finish',
      ),
    );
  }
}
