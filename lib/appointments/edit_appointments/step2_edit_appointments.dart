import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class AppointmentEditPageStep2 extends StatefulWidget {
  final Appointment appointment;
  final Function(int) onPageChange;

  const AppointmentEditPageStep2(
      {Key? key, required this.appointment, required this.onPageChange})
      : super(key: key);

  @override
  AppointmentEditPageStep2State createState() =>
      AppointmentEditPageStep2State();
}

class AppointmentEditPageStep2State extends State<AppointmentEditPageStep2> {
  Future<void> _showDatePicker(int index) async {
    final DateTime? pickedDateRange = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));

    if (pickedDateRange != null && mounted) {
      // Check if the widget is still mounted
      final TimeOfDay? pickedStartTime =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());

      if (pickedStartTime != null && mounted) {
        // Check again after async gap
        final TimeOfDay? pickedEndTime = await showTimePicker(
            context: context, initialTime: pickedStartTime);

        if (pickedEndTime != null && mounted) {
          // Check again after async gap
          _updateTimeSlots(
              pickedDateRange, pickedStartTime, pickedEndTime, index);
        }
      }
    }
  }

  void _deleteDate(int index) {
    setState(() {
      widget.appointment.availableDates.removeAt(index);
      widget.appointment.availableTimeSlots.removeAt(index);
    });
  }

  void _addDate() {
    setState(() {
      final now = DateTime.now();
      final timeSlot = TimeSlot(
          start: now,
          end: now.add(const Duration(hours: 1)),
          expirationDate: now.add(const Duration(days: 7)));
      widget.appointment.availableDates.add(now);
      widget.appointment.availableTimeSlots.add(timeSlot);
    });
  }

  Widget buildAddDatesButton() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(timeFontSize * 3.0),
        padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
        foregroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[900]
            : const Color.fromARGB(255, 255, 255, 255),
        backgroundColor: Theme.of(context).brightness == Brightness.light
            ? Colors.grey[100]
            : Colors.grey[900],
        shape: const CircleBorder(),
      ),
      onPressed: () {
        _addDate();
      },
      child: Icon(Icons.add, size: timeFontSize * 1.5),
    );
  }

  void _updateTimeSlots(DateTime pickedDateRange, TimeOfDay pickedStartTime,
      TimeOfDay pickedEndTime, int index) {
    final startDateTime = DateTime(pickedDateRange.year, pickedDateRange.month,
        pickedDateRange.day, pickedStartTime.hour, pickedStartTime.minute);
    final endDateTime = DateTime(pickedDateRange.year, pickedDateRange.month,
        pickedDateRange.day, pickedEndTime.hour, pickedEndTime.minute);
    setState(() {
      widget.appointment.availableDates[index] = pickedDateRange;
      widget.appointment.availableTimeSlots[index].start = startDateTime;
      widget.appointment.availableTimeSlots[index].end = endDateTime;
    });
  }

  Widget _buildDateButton(DateTime date, int index) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    final dayOfWeek = DateFormat.EEEE().format(date);
    final dayOfMonth = DateFormat.d().format(date);
    final year = DateFormat.y().format(date);
    final buttonWidth = MediaQuery.of(context).size.width *
        (MediaQuery.of(context).size.shortestSide >= 600 ? 0.7 : 0.9);
    return SizedBox(
      width: buttonWidth,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
            foregroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey[900]
                : const Color.fromARGB(255, 255, 255, 255),
            backgroundColor: Theme.of(context).brightness == Brightness.light
                ? Colors.grey[100]
                : Colors.grey[900]),
        onPressed: () => _showDatePicker(index),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                '$dayOfWeek $dayOfMonth $year',
                style: TextStyle(fontSize: timeFontSize),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${DateFormat.jm().format(widget.appointment.availableTimeSlots[index].start)} ${widget.appointment.availableTimeSlots[index].amPm}',
                    style: TextStyle(
                      fontSize: timeFontSize - 2,
                    ),
                  ),
                  const Text(' - '),
                  Text(
                    '${DateFormat.jm().format(
                      widget.appointment.availableTimeSlots[index].end,
                    )} ${widget.appointment.availableTimeSlots[index].amPm}',
                    style: TextStyle(
                      fontSize: timeFontSize - 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ...

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    (MediaQuery.of(context).size.shortestSide >= 600 ? 0.7 : 0.9);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Text(
              'create_appointment_date_time_selection'.tr(),
              style: TextStyle(
                fontSize: timeFontSize,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.light
                    ? const Color(0xff004B96)
                    : Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: widget.appointment.availableDates.isEmpty
                ? Center(
                    child: Text(
                    'no_dates_added'.tr(),
                    style: TextStyle(
                      fontSize: timeFontSize,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.light
                          ? const Color(0xff004B96)
                          : Colors.white,
                    ),
                  ))
                : ListView.separated(
                    itemCount: widget.appointment.availableDates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Stack(
                            children: [
                              _buildDateButton(
                                  widget.appointment.availableDates[index],
                                  index),
                              Positioned(
                                top: -13,
                                right: -13,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey[700]
                                        : Colors.white,
                                  ),
                                  onPressed: () => _deleteDate(index),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          buildAddDatesButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
