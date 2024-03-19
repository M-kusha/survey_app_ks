import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/create/step4_create_appointment.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/appointments/firebase/appointment_services.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/colors.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class Step3CreateAppointment extends StatefulWidget {
  const Step3CreateAppointment({super.key});

  @override
  State<Step3CreateAppointment> createState() => Step3CreateAppointmentState();
}

class Step3CreateAppointmentState extends State<Step3CreateAppointment> {
  late Appointment _newAppointment;
  final AppointmentService _appointmentService = AppointmentService();
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 1));

  Future<void> _onNextPressed() async {
    if (_newAppointment.isValid()) {
      await _appointmentService.createAppointment(_newAppointment);

      if (!context.mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Step4CreateAppointment(
            appointment: _newAppointment,
          ),
        ),
      );
    } else {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _newAppointment =
        ModalRoute.of(context)!.settings.arguments as Appointment? ??
            Appointment(
              title: '',
              description: '',
              availableDates: [],
              availableTimeSlots: [],
              appointmentId: '',
              confirmedTimeSlots: [],
              expirationDate: DateTime.now(),
              participationCount: 0,
              participants: [],
              creationDate: DateTime.now(),
            );
  }

  // function to show date picker
  Future<void> _selectExpirationDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _expirationDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _expirationDate) {
      setState(() {
        _expirationDate = pickedDate;
        _newAppointment.expirationDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
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
        backgroundColor: ThemeBasedAppColors.getColor(context, 'appbarColor'),
      ),
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
                shadowColor:
                    ThemeBasedAppColors.getColor(context, 'buttonColor'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: InkWell(
                  onTap: () => _selectExpirationDate(context),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event,
                            size: timeFontSize * 2.5,
                            color: ThemeBasedAppColors.getColor(
                                context, 'buttonColor')),
                        const SizedBox(height: 20),
                        Text(
                          DateFormat("EEEE, d MMMM y").format(_expirationDate),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: timeFontSize * 1.1,
                            fontWeight: FontWeight.bold,
                            color: ThemeBasedAppColors.getColor(
                                context, 'listTileColor'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'tap_to_change'.tr(),
                          style: TextStyle(
                            fontSize: timeFontSize * 0.8,
                            color: ThemeBasedAppColors.getColor(
                                context, 'listTileColor'),
                          ),
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
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }

  Widget buildAddDatesButton() {
    final timeFontSize = getTimeFontSize(context, 13);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
        backgroundColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(6),
      ),
      onPressed: () {
        setState(() {
          _selectExpirationDate(context);
        });
      },
      child: Icon(Icons.calendar_month_outlined, size: timeFontSize * 2.5),
    );
  }
}
