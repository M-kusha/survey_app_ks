import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AppointmentEditPageStep3 extends StatefulWidget {
  final Appointment appointment;
  final Function(int) onPageChange;

  const AppointmentEditPageStep3({
    Key? key,
    required this.appointment,
    required this.onPageChange,
  }) : super(key: key);

  @override
  AppointmentEditPageStep3State createState() =>
      AppointmentEditPageStep3State();
}

class AppointmentEditPageStep3State extends State<AppointmentEditPageStep3> {
  late Appointment appointment;
  DateTime _expirationDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    appointment = widget.appointment;
    _expirationDate = appointment.expirationDate;
  }

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
          Padding(
            padding: EdgeInsets.all(timeFontSize * 1.5),
            child: Column(
              children: [
                Text(
                  'select_voting_expiration_date'.tr(),
                  style: TextStyle(
                    fontSize: timeFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: Card(
                elevation: 5,
                shadowColor: getButtonColor(context),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  onTap: () => _selectExpirationDate(context),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.event,
                          size: timeFontSize * 2.5,
                          color: getButtonColor(context),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          DateFormat("EEEE, d MMMM y").format(_expirationDate),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: timeFontSize * 1.1,
                              fontWeight: FontWeight.bold,
                              color: getListTileColor(context)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'tap_to_change'.tr(),
                          style: TextStyle(
                              fontSize: timeFontSize * 0.8,
                              color: getListTileColor(context)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
