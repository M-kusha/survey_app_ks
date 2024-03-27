import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:survey_app_ks/survey_pages/user_survey/step2_participate_survey.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:survey_app_ks/utilities/reusable_widgets.dart';
import 'package:survey_app_ks/utilities/text_style.dart';

class Step1ParticipateSurvey extends StatelessWidget {
  final Survey survey;
  final Participant participant;
  final String imageProfile;

  const Step1ParticipateSurvey(
      {Key? key,
      required this.survey,
      required this.participant,
      required this.imageProfile})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (survey.surveyType == SurveyType.survey) {
      Future.microtask(() {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Step2ParticipateSurvey(
              survey: survey,
              participant: participant,
              imageProfile: '',
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('survey_participation_rules'.tr()),
        centerTitle: true,
        backgroundColor: getAppbarColor(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Card(
            elevation: 5,
            shadowColor: getButtonColor(context),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildWelcomeCard(
                      context,
                      getButtonColor(context),
                    ),
                    const SizedBox(height: 10),
                    _buildRulesCard(
                      context,
                      getButtonColor(context),
                    ),
                    if (survey.timeLimitPerQuestion > 0)
                      _buildTimerCard(
                        context,
                        getButtonColor(context),
                      ),
                    const SizedBox(height: 10),
                  ],
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
            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) => Step2ParticipateSurvey(
                survey: survey,
                participant: participant,
                imageProfile: imageProfile,
              ),
            ));
          },
          buttonText: 'start_survey'.tr(),
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(BuildContext context, Color buttonColor) {
    return Card(
      elevation: 5.0,
      shadowColor: buttonColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${'welcome'.tr()}${participant.name}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text(
              'read_rules'.tr(),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesCard(BuildContext context, Color buttonColor) {
    return Card(
      elevation: 5,
      shadowColor: buttonColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'rules_for_participating'.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(),
            ),
            const SizedBox(height: 10),
            _buildRulesBasedOnSurveyType(),
          ],
        ),
      ),
    );
  }

  Widget _buildRulesBasedOnSurveyType() {
    switch (survey.surveyType) {
      case SurveyType.test:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('single_choice_rule'.tr()),
            const SizedBox(height: 5),
            Text('multiple_choice_rule'.tr()),
            const SizedBox(height: 5),
            Text('text_question_rule'.tr()),
            const SizedBox(height: 5),
            Text('hint_for_survey'.tr()),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildTimerCard(BuildContext context, Color buttonColor) {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      elevation: 4.0,
      shadowColor: Colors.red.withOpacity(0.5), // Red shadow for emphasis
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          // Center the timer rule text
          child: Text(
            '${'time_limit_text_1'.tr()} ${survey.timeLimitPerQuestion} ${'time_limit_text_2'.tr()}',
            style: const TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.red), // Red text for urgency
          ),
        ),
      ),
    );
  }
}
