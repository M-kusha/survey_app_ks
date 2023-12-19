import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_questionary/create_survey/create_survey_step_2.dart';
import 'package:survey_app_ks/survey_questionary/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:uuid/uuid.dart';

class CreateTrainingSurveyStep1 extends StatefulWidget {
  const CreateTrainingSurveyStep1({
    super.key,
  });

  @override
  State<CreateTrainingSurveyStep1> createState() =>
      _CreateTrainingSurveyStep1State();
}

class _CreateTrainingSurveyStep1State extends State<CreateTrainingSurveyStep1> {
  final TextEditingController _surveyNameController = TextEditingController();
  final TextEditingController _surveyDescriptionController =
      TextEditingController();
  final TextEditingController _surveyDeadlineController =
      TextEditingController();
  DateTime? _selectedDate;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime now = DateTime.now();
    final DateTime tomorrow = DateTime(now.year, now.month, now.day + 1);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: tomorrow,
      firstDate: tomorrow,
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        String formattedDate =
            DateFormat('EEEE d MMMM y', 'en_US').format(picked);
        _surveyDeadlineController.text = formattedDate;
      });
    }
  }

  void _showSnackbar(BuildContext context, String message) {
    final snackBar = SnackBar(
      content: Text(
        message.tr(),
        textAlign: TextAlign.center,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('create_training_survey').tr(),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'training_survey_tip_1'.tr(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Text(
                  'survey_name'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: _surveyNameController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    hintText: 'enter_survey_name'.tr(),
                    hintStyle: TextStyle(fontSize: timeFontSize),
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16.0),
                Text(
                  'survey_description'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: _surveyDescriptionController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    hintText: 'enter_survey_description'.tr(),
                    hintStyle: TextStyle(fontSize: timeFontSize),
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'survey_deadline'.tr(),
                  style: TextStyle(fontSize: timeFontSize),
                ),
                const SizedBox(height: 16.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: TextField(
                        controller: _surveyDeadlineController,
                        readOnly: true,
                        decoration: InputDecoration(
                          hintText: 'select_deadline'.tr(),
                          hintStyle: TextStyle(fontSize: timeFontSize),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10.0),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_month_outlined,
                                size: 30),
                            onPressed: () => _selectDate(context),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16.0),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: _surveyNameController.text.isEmpty ||
                        _surveyDescriptionController.text.isEmpty ||
                        _selectedDate == null
                    ? () {
                        _showSnackbar(context, 'fill_all_fields'.tr());
                      }
                    : null,
                child: ElevatedButton(
                  onPressed: _surveyNameController.text.isEmpty ||
                          _surveyDescriptionController.text.isEmpty ||
                          _selectedDate == null
                      ? null
                      : () {
                          final survey = SurveyQuestionaryType(
                            surveyName: _surveyNameController.text,
                            surveyDescription:
                                _surveyDescriptionController.text,
                            timeCreated: DateTime.now(),
                            questions: [],
                            correctAnswers: [],
                            id: const Uuid().v4(),
                            deadline: _selectedDate,
                            participants: [],
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateTrainingSurveyStep2(
                                survey: survey,
                                onSurveyCreated: (survey) {
                                  Navigator.pop(context, survey);
                                },
                              ),
                            ),
                          );
                        },
                  child: const Text('next').tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
