import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:survey_app_ks/settings/font_size_provider.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/bottom_navigation.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/tablet_size.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class Step3ParticipateSurvey extends StatefulWidget {
  final Participant participant;
  final Survey survey;

  const Step3ParticipateSurvey({
    Key? key,
    required this.participant,
    required this.survey,
  }) : super(key: key);

  @override
  State<Step3ParticipateSurvey> createState() => Step3ParticipateSurveyState();
}

class Step3ParticipateSurveyState extends State<Step3ParticipateSurvey> {
  @override
  Widget build(BuildContext context) {
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
          title: Text(
            widget.survey.surveyType == SurveyType.survey
                ? 'survey_finished'.tr()
                : 'test_finished'.tr(),
            style: TextStyle(fontSize: timeFontSize * 1.5),
          ),
          centerTitle: true,
          backgroundColor: getAppbarColor(context)),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              height: 300,
              child: Card(
                elevation: 5,
                shadowColor: getButtonColor(context),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.survey.surveyType == SurveyType.survey
                            ? 'thank_you'.tr()
                            : 'thank_you_participation'.tr(),
                        style: TextStyle(
                            fontSize: timeFontSize + 2,
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      const SizedBox(height: 20),
                      Text(
                        widget.survey.surveyType == SurveyType.survey
                            ? 'survey_finished_message'.tr()
                            : 'test_finished_message'.tr(),
                        style: TextStyle(fontSize: timeFontSize + 2),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: buildBottomElevatedButton(
          context: context,
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                builder: (context) => const BottomNavigation(initialIndex: 2),
              ),
              (route) => false,
            );
          },
          buttonText: 'return_back'.tr(),
        ),
      ),
    );
  }
}
