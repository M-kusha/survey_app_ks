import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class Step2CreateAppointment extends StatefulWidget {
  const Step2CreateAppointment({Key? key}) : super(key: key);

  @override
  Step2CreateAppointmentState createState() => Step2CreateAppointmentState();
}

class Step2CreateAppointmentState extends State<Step2CreateAppointment> {
  late Appointment _newAppointment;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _newAppointment =
        ModalRoute.of(context)!.settings.arguments as Appointment? ??
            Appointment(
              title: '',
              description: '',
              participants: [],
              availableDates: [],
              availableTimeSlots: [],
              appointmentId: '',
              confirmedTimeSlots: [],
              expirationDate: DateTime.now(),
              participationCount: 0,
              creationDate: DateTime.now(),
            );
  }

  void _onNextPressed() async {
    if (_newAppointment.availableDates.isNotEmpty) {
      Navigator.pushNamed(context, '/create_appointment_step_3',
          arguments: _newAppointment);
    }
  }

  void _addDate() {
    setState(() {
      final now = DateTime.now();
      final timeSlot = TimeSlot(
          start: now,
          end: now.add(const Duration(hours: 1)),
          expirationDate: now.add(const Duration(days: 7)));
      _newAppointment.availableDates.add(now);
      _newAppointment.availableTimeSlots.add(timeSlot);
    });
  }

  void _updateTimeSlots(DateTime pickedDateRange, TimeOfDay pickedStartTime,
      TimeOfDay pickedEndTime, int index) {
    final startDateTime = DateTime(pickedDateRange.year, pickedDateRange.month,
        pickedDateRange.day, pickedStartTime.hour, pickedStartTime.minute);
    final endDateTime = DateTime(pickedDateRange.year, pickedDateRange.month,
        pickedDateRange.day, pickedEndTime.hour, pickedEndTime.minute);
    setState(() {
      _newAppointment.availableDates[index] = pickedDateRange;
      _newAppointment.availableTimeSlots[index].start = startDateTime;
      _newAppointment.availableTimeSlots[index].end = endDateTime;
    });
  }

  Future<void> _showDatePicker(int index) async {
    final DateTime? pickedDateRange = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));

    if (pickedDateRange != null && mounted) {
      final TimeOfDay? pickedStartTime =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());

      if (pickedStartTime != null && mounted) {
        final TimeOfDay? pickedEndTime = await showTimePicker(
            context: context, initialTime: pickedStartTime);

        if (pickedEndTime != null && mounted) {
          _updateTimeSlots(
              pickedDateRange, pickedStartTime, pickedEndTime, index);
        }
      }
    }
  }

  Widget _buildDateButton(DateTime date, int index) {
    final dayOfWeek = DateFormat.EEEE().format(date);
    final dayOfMonth = DateFormat.d().format(date);
    final month = DateFormat.MMM().format(date);
    final year = DateFormat.y().format(date);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return InkWell(
      onTap: () => _showDatePicker(index),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: getButtonColor(context),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.5),
              spreadRadius: 1,
              blurRadius: 7,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(Icons.calendar_today,
                color: getButtonColor(context), size: timeFontSize * 1.5),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$dayOfWeek, $month $dayOfMonth, $year',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: timeFontSize * 1.2,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${DateFormat.jm().format(_newAppointment.availableTimeSlots[index].start)} - ${DateFormat.jm().format(_newAppointment.availableTimeSlots[index].end)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: timeFontSize,
                        color: getListTileColor(context)),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _removeDate(index),
              child: Icon(Icons.close,
                  color: Colors.redAccent, size: timeFontSize * 1.5),
            ),
          ],
        ),
      ),
    );
  }

  void _removeDate(int index) {
    setState(() {
      _newAppointment.availableDates.removeAt(index);
      _newAppointment.availableTimeSlots.removeAt(index);
    });
  }

  Widget buildAddDatesButton(BuildContext context) {
    final timeFontSize = getTimeFontSize(context, 14);

    return FloatingActionButton(
      onPressed: _addDate,
      backgroundColor: getButtonColor(context),
      child: Icon(Icons.add, size: timeFontSize * 2),
    );
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
          backgroundColor: getAppbarColor(context)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final verticalSpacing = constraints.maxHeight * 0.02;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: timeFontSize * 2.0),
                child: Text(
                  'create_appointment_date_time_selection'.tr(),
                  style: TextStyle(
                      fontSize: timeFontSize * 1.3,
                      fontWeight: FontWeight.bold,
                      color: getListTileColor(context)),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _newAppointment.availableDates.isEmpty
                    ? Center(
                        child: Text(
                        'no_dates_added'.tr(),
                        style: TextStyle(
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.bold,
                          color: getListTileColor(context),
                        ),
                      ))
                    : ListView.builder(
                        itemCount: _newAppointment.availableDates.length,
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              _buildDateButton(
                                  _newAppointment.availableDates[index], index),
                              SizedBox(height: verticalSpacing),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              buildAddDatesButton(context),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }
}
