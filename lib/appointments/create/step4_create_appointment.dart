import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
    final fontSizeProvider = Provider.of<FontSizeProvider>(context);
    final fontSize = fontSizeProvider.fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
          title: Text(
            'create_appointment'.tr(),
            style: TextStyle(
              fontSize: timeFontSize * 1.5,
            ),
          ),
          centerTitle: true,
          backgroundColor: getAppbarColor(context)),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Card(
              elevation: 5,
              shadowColor: getButtonColor(context),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: timeFontSize * 3,
                      color: getButtonColor(context),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'appointment_created_successfully'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: timeFontSize * 1.2,
                        fontWeight: FontWeight.bold,
                        color: getListTileColor(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'share_id_information'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: timeFontSize),
                    ),
                    const SizedBox(height: 30),
                    InkWell(
                      onTap: () => copyToClipboard(context,
                          widget.appointment.appointmentId, timeFontSize),
                      child: Container(
                        decoration: BoxDecoration(
                          color: getAppbarColor(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 20),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.content_copy, size: timeFontSize * 1.2),
                            const SizedBox(width: 10),
                            Text(
                              '${'appointment_id'.tr()} ${widget.appointment.appointmentId}',
                              style: TextStyle(fontSize: timeFontSize - 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'finish',
      ),
    );
  }

  Widget buildInformationCard(BuildContext context,
      {required String title,
      required String subtitle,
      required IconData iconData,
      required double fontSize}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(iconData, size: fontSize * 1.5),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: fontSize, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(subtitle, style: TextStyle(fontSize: fontSize)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void copyToClipboard(BuildContext context, String text, double fontSize) {
    Clipboard.setData(ClipboardData(text: text));
    UIUtils.showSnackBar(context, 'appointment_id_copied');
  }
}
