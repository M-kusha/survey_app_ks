// ignore_for_file: unnecessary_null_comparison

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class CreateSurveyStep2 extends StatefulWidget {
  const CreateSurveyStep2({Key? key}) : super(key: key);

  @override
  CreateSurveyStep2State createState() => CreateSurveyStep2State();
}

class CreateSurveyStep2State extends State<CreateSurveyStep2> {
  late Survey _newSurvey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _newSurvey = ModalRoute.of(context)!.settings.arguments as Survey? ??
        Survey(
          title: '',
          description: '',
          availableDates: [],
          availableTimeSlots: [],
          password: '',
          id: '',
          expirationDate: DateTime.now(),
        );
  }

  void _addDate() {
    setState(() {
      final now = DateTime.now();
      final timeSlot = TimeSlot(
          start: now,
          end: now.add(const Duration(hours: 1)),
          expirationDate: now.add(const Duration(days: 7)));
      _newSurvey.availableDates.add(now);
      _newSurvey.availableTimeSlots.add(timeSlot);
    });
  }

  void _updateTimeSlots(DateTime pickedDateRange, TimeOfDay pickedStartTime,
      TimeOfDay pickedEndTime, int index) {
    final startDateTime = DateTime(pickedDateRange.year, pickedDateRange.month,
        pickedDateRange.day, pickedStartTime.hour, pickedStartTime.minute);
    final endDateTime = DateTime(pickedDateRange.year, pickedDateRange.month,
        pickedDateRange.day, pickedEndTime.hour, pickedEndTime.minute);
    setState(() {
      _newSurvey.availableDates[index] = pickedDateRange;
      _newSurvey.availableTimeSlots[index].start = startDateTime;
      _newSurvey.availableTimeSlots[index].end = endDateTime;
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
    final year = DateFormat.y().format(date);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
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
              Text('$dayOfWeek $dayOfMonth $year',
                  style: TextStyle(
                    fontSize: timeFontSize,
                  )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _newSurvey.availableTimeSlots[index].start != null
                        ? '${DateFormat.jm().format(
                            _newSurvey.availableTimeSlots[index].start,
                          )} ${_newSurvey.availableTimeSlots[index].amPm}'
                        : 'Start Time',
                    style: TextStyle(
                      fontSize: timeFontSize,
                    ),
                  ),
                  const Text(' - '),
                  Text(
                    _newSurvey.availableTimeSlots[index].end != null
                        ? '${DateFormat.jm().format(
                            _newSurvey.availableTimeSlots[index].end,
                          )} ${_newSurvey.availableTimeSlots[index].amPm}'
                        : 'End Time',
                    style: TextStyle(
                      fontSize: timeFontSize,
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

  Widget buildNextButton(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: _newSurvey.availableDates.isEmpty
                ? null
                : () {
                    Navigator.pushNamed(context, '/create_survey_3',
                        arguments: _newSurvey);
                  },
            style: ElevatedButton.styleFrom(
              minimumSize: Size.fromHeight(timeFontSize * 3.0),
              padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
            ),
            child: Text(
              'next'.tr(),
              style: TextStyle(
                fontSize: timeFontSize,
              ),
            ),
          ),
          const SizedBox(height: 16.0),
        ],
      ),
    );
  }

  Widget buildAddDatesButton(BuildContext context) {
    final timeFontSize = getTimeFontSize(context, 13);

    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: const Color(0xff004B96),
        shape: const CircleBorder(),
        padding: EdgeInsets.all(timeFontSize),
      ),
      onPressed: () {
        _addDate();
      },
      child: Icon(Icons.add, size: timeFontSize * 2.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
        title: Text('create_survey_step_1'.tr(),
            style: TextStyle(
              fontSize: timeFontSize,
            )),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final verticalSpacing = constraints.maxHeight * 0.03;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.only(top: timeFontSize * 2.0),
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
                child: _newSurvey.availableDates.isEmpty
                    ? Center(
                        child: Text(
                        'no_dates_added'.tr(),
                        style: TextStyle(
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.bold,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? const Color(0xff004B96)
                                  : Colors.white,
                        ),
                      ))
                    : ListView.builder(
                        itemCount: _newSurvey.availableDates.length,
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              _buildDateButton(
                                  _newSurvey.availableDates[index], index),
                              SizedBox(
                                  height: verticalSpacing), // Use SizedBox here
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
      bottomNavigationBar: buildNextButton(context),
    );
  }
}
