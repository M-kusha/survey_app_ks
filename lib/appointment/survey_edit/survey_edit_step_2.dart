import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class SurveyEditPageStep2 extends StatefulWidget {
  final Survey survey;
  final Function(int) onPageChange;

  const SurveyEditPageStep2(
      {Key? key, required this.survey, required this.onPageChange})
      : super(key: key);

  @override
  SurveyEditPageStep2State createState() => SurveyEditPageStep2State();
}

class SurveyEditPageStep2State extends State<SurveyEditPageStep2> {
  Future<void> _showDatePicker(int index) async {
    final DateTime? pickedDateRange = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));

    if (pickedDateRange != null) {
      final TimeOfDay? pickedStartTime =
          await showTimePicker(context: context, initialTime: TimeOfDay.now());
      if (pickedStartTime != null) {
        final TimeOfDay? pickedEndTime = await showTimePicker(
            context: context, initialTime: pickedStartTime);
        if (pickedEndTime != null) {
          _updateTimeSlots(
              pickedDateRange, pickedStartTime, pickedEndTime, index);
        }
      }
    }
  }

  void _deleteDate(int index) {
    setState(() {
      widget.survey.availableDates.removeAt(index);
      widget.survey.availableTimeSlots.removeAt(index);
    });
  }

  void _addDate() {
    setState(() {
      final now = DateTime.now();
      final timeSlot = TimeSlot(
          start: now,
          end: now.add(const Duration(hours: 1)),
          expirationDate: now.add(const Duration(days: 7)));
      widget.survey.availableDates.add(now);
      widget.survey.availableTimeSlots.add(timeSlot);
    });
  }

  Widget buildAddDatesButton() {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: Size.fromHeight(timeFontSize * 3.0),
        padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xff004B96),
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
      widget.survey.availableDates[index] = pickedDateRange;
      widget.survey.availableTimeSlots[index].start = startDateTime;
      widget.survey.availableTimeSlots[index].end = endDateTime;
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
                    '${DateFormat.jm().format(widget.survey.availableTimeSlots[index].start)} ${widget.survey.availableTimeSlots[index].amPm}',
                    style: TextStyle(
                      fontSize: timeFontSize - 2,
                    ),
                  ),
                  const Text(' - '),
                  Text(
                    '${DateFormat.jm().format(
                      widget.survey.availableTimeSlots[index].end,
                    )} ${widget.survey.availableTimeSlots[index].amPm}',
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
              'create_survey_date_time_selection'.tr(),
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
            child: widget.survey.availableDates.isEmpty
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
                    itemCount: widget.survey.availableDates.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return Column(
                        children: [
                          Stack(
                            children: [
                              _buildDateButton(
                                  widget.survey.availableDates[index], index),
                              Positioned(
                                top: -13,
                                right: -13,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.white,
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
