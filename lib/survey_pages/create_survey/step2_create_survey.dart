import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/survey_pages/create_survey/step3_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/carosel_slider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';

class Step2CreateSurvey extends StatefulWidget {
  const Step2CreateSurvey({
    Key? key,
    required this.survey,
    required this.onSurveyCreated,
  }) : super(key: key);

  final Survey survey;
  final Function(Survey) onSurveyCreated;

  @override
  State<Step2CreateSurvey> createState() => Step2CreateSurveyState();
}

class Step2CreateSurveyState extends State<Step2CreateSurvey> {
  CarouselController carouselController = CarouselController();
  DateTime _expirationDate = DateTime.now().add(const Duration(days: 1));
  int selectedTimeLimit = 0;
  int typeIndex = 0;

  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'create_survey'.tr(),
          style: TextStyle(fontSize: fontSize * 1.5),
        ),
        centerTitle: true,
        backgroundColor: getAppbarColor(context),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildDateCard(fontSize),
              const SizedBox(height: 20),
              buildSurveyTypeCard(fontSize),
              const SizedBox(height: 20),
              buildTimeLimitCard(fontSize),
            ],
          ),
        ),
      ),
      bottomNavigationBar: buildBottomElevatedButton(
        context: context,
        onPressed: _onNextPressed,
        buttonText: 'next',
      ),
    );
  }

  Widget buildDateCard(double timeFontSize) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Card(
        elevation: 1,
        shadowColor: getButtonColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
                    color: getListTileColor(context),
                  ),
                ),
                const SizedBox(height: 20),
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
    );
  }

  Widget buildSurveyTypeCard(double timeFontSize) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Card(
        elevation: 1,
        shadowColor: getButtonColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.category,
                size: timeFontSize * 2.5,
                color: getButtonColor(context),
              ),
              const SizedBox(height: 20),
              DropdownButton<SurveyType>(
                value: widget.survey.surveyType,
                items: getSurveyTypeOptions(context),
                style:
                    TextStyle(color: getListTileColor(context), fontSize: 16),
                underline: Container(
                  height: 1,
                  color: getButtonColor(context),
                ),
                onChanged: (SurveyType? newValue) {
                  setState(() {
                    widget.survey.surveyType = newValue!;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                'choose_survey_type'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: timeFontSize * 0.8,
                    color: getListTileColor(context)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTimeLimitCard(double timeFontSize) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Card(
        elevation: 1,
        shadowColor: getButtonColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer,
                size: timeFontSize * 2.5,
                color: getButtonColor(context),
              ),
              const SizedBox(height: 20),
              NumberCarouselSlider(
                onNumberChanged: onNumberCarouselChanged,
                startValue: selectedTimeLimit,
                carouselController: carouselController,
              ),
              const SizedBox(height: 8),
              Text(
                'choose_time_limit'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: timeFontSize * 0.8,
                  color: getListTileColor(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onNumberCarouselChanged(int newValue) {
    setState(() {
      selectedTimeLimit = newValue;
    });
  }

  List<DropdownMenuItem<SurveyType>> getSurveyTypeOptions(
      BuildContext context) {
    return SurveyType.values.map((type) {
      String label;
      switch (type) {
        case SurveyType.survey:
          label = "standart_survey".tr();
          break;
        case SurveyType.test:
          label = "testing_survey".tr();
          break;
      }
      return DropdownMenuItem(
        value: type,
        child: Text(label),
      );
    }).toList();
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
      });
    }
  }

  void _onNextPressed() {
    widget.survey.deadline = _expirationDate;
    widget.survey.timeLimitPerQuestion = selectedTimeLimit;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTrainingSurveyStep3(
          survey: widget.survey,
        ),
      ),
    );
  }
}
