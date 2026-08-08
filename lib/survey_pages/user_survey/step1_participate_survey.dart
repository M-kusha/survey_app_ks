import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/survey_pages/user_survey/step2_participate_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';

class Step1ParticipateSurvey extends StatefulWidget {
  final Survey survey;
  final Participant participant;
  final String imageProfile;

  const Step1ParticipateSurvey({
    super.key,
    required this.survey,
    required this.participant,
    required this.imageProfile,
  });

  @override
  State<Step1ParticipateSurvey> createState() => _Step1ParticipateSurveyState();
}

class _Step1ParticipateSurveyState extends State<Step1ParticipateSurvey> {
  @override
  void initState() {
    super.initState();
    // A plain survey has no rules to read, so skip straight to the questions.
    // Done once after the first frame rather than from build(), which can run
    // many times and would queue a duplicate navigation on each rebuild.
    if (widget.survey.surveyType == SurveyType.survey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Step2ParticipateSurvey(
              survey: widget.survey,
              participant: widget.participant,
              imageProfile: '',
            ),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    _buildWelcomeCard(context, getButtonColor(context)),
                    const SizedBox(height: 10),
                    _buildRulesCard(context, getButtonColor(context)),
                    if (widget.survey.timeLimitPerQuestion > 0)
                      _buildTimerCard(context, getButtonColor(context)),
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
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => Step2ParticipateSurvey(
                  survey: widget.survey,
                  participant: widget.participant,
                  imageProfile: widget.imageProfile,
                ),
              ),
            );
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${'welcome'.tr()}${widget.participant.name}!',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Text('read_rules'.tr(), textAlign: TextAlign.center),
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
    switch (widget.survey.surveyType) {
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
      shadowColor: Colors.red.withValues(alpha: 0.5), // Red shadow for emphasis
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          // Center the timer rule text
          child: Text(
            '${'time_limit_text_1'.tr()} ${widget.survey.timeLimitPerQuestion} ${'time_limit_text_2'.tr()}',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.red,
            ), // Red text for urgency
          ),
        ),
      ),
    );
  }
}
