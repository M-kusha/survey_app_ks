import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/appointment/survey_class.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';

class CreateSurveyStep3 extends StatefulWidget {
  const CreateSurveyStep3({super.key});

  @override
  State<CreateSurveyStep3> createState() => CreateSurveyStep3State();
}

class CreateSurveyStep3State extends State<CreateSurveyStep3> {
  late Survey _newSurvey;
  bool _expirationDatePressed = false;
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 1));

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
        _newSurvey.expirationDate = pickedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
        title: Text('create_survey_step_1'.tr(),
            style: TextStyle(fontSize: timeFontSize)),
        centerTitle: true,
      ),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: Size.fromHeight(timeFontSize * 3.0),
                padding: EdgeInsets.symmetric(vertical: timeFontSize * 0.5),
              ),
              onPressed: _expirationDatePressed == false
                  ? null
                  : () {
                      Navigator.pushNamed(context, '/create_survey_4',
                          arguments: _newSurvey);
                    },
              child:
                  Text('next'.tr(), style: TextStyle(fontSize: timeFontSize)),
            ),
            const SizedBox(height: 16.0),
          ],
        ),
      ),
    );
  }

  Widget buildAddDatesButton() {
    final timeFontSize = getTimeFontSize(context, 13);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        padding: const EdgeInsets.all(6),
      ),
      onPressed: () {
        setState(() {
          _expirationDatePressed = true;
          _selectExpirationDate(context);
        });
      },
      child: Icon(Icons.calendar_month_outlined, size: timeFontSize * 2.5),
    );
  }
}
