import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';

class AppointmentEditPageStep4 extends StatefulWidget {
  final Appointment appointment;
  final TimeSlot timeSlot;
  final Function(int) onPageChange;

  const AppointmentEditPageStep4({
    super.key,
    required this.appointment,
    required this.onPageChange,
    required this.timeSlot,
  });

  @override
  AppointmentEditPageStep4State createState() =>
      AppointmentEditPageStep4State();
}

class AppointmentEditPageStep4State extends State<AppointmentEditPageStep4> {
  bool isChecked = false;

  @override
  void initState() {
    super.initState();
    isChecked = widget.appointment.confirmedTimeSlots.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final themeColor = Theme.of(context).primaryColor;

    return Scaffold(
      body: Center(
        child: Card(
          elevation: 5,
          shadowColor: getButtonColor(context),
          margin: const EdgeInsets.all(24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    'editing_confirmation_status'.tr(),
                    style: TextStyle(
                      fontSize: fontSize * 1.1,
                      fontWeight: FontWeight.bold,
                      color: getButtonColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'editing_confirmation_status_tip'.tr(),
                  style: TextStyle(fontSize: fontSize),
                ),
                const SizedBox(height: 24),
                CheckboxListTile(
                  title: Text(
                    'confirmation_status'.tr(),
                    style: TextStyle(
                        fontSize: fontSize, fontWeight: FontWeight.bold),
                  ),
                  value: isChecked,
                  onChanged: (value) => _handleCheckboxChanged(value),
                  activeColor: themeColor,
                  checkColor: getButtonColor(context),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCheckboxChanged(bool? value) {
    if (!value! && widget.appointment.confirmedTimeSlots.isNotEmpty) {
      _showConfirmationDialog();
    } else {
      setState(() => isChecked = value);
    }
  }

  void _showConfirmationDialog() {
    final fontSize =
        Provider.of<FontSizeProvider>(context, listen: false).fontSize;

    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Center(
          child: Text(
            'editing_confirmation_status_dialog_title'.tr(),
            style: TextStyle(fontSize: fontSize),
          ),
        ),
        content: Text(
          'editing_confirmation_status_dialog_content'.tr(),
          style: TextStyle(fontSize: fontSize - 2),
        ),
        actions: <Widget>[
          TextButton(
            child:
                Text('cancel'.tr(), style: TextStyle(fontSize: fontSize - 2)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('confirm'.tr(),
                style: TextStyle(fontSize: fontSize - 2, color: Colors.red)),
            onPressed: () {
              setState(() {
                widget.appointment.confirmedTimeSlots.clear();
                isChecked = false;
              });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
