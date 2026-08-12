import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/widgets/creation_success.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';

class Step4CreateSurvey extends StatelessWidget {
  const Step4CreateSurvey({super.key, required this.survey});

  final Survey survey;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final isTest = survey.surveyType == SurveyType.test;

    return CreationSuccessPage(
      title: 'survey_created_successfully'.tr(),
      name: survey.surveyName,
      facts: [
        (
          icon: isTest ? Icons.workspace_premium_outlined : Icons.poll_outlined,
          label: (isTest ? 'label_test' : 'label_survey').tr(),
        ),
        (
          icon: Icons.help_outline_rounded,
          label: 'question_count'.tr(
            namedArgs: {'count': '${survey.questions.length}'},
          ),
        ),
        (
          icon: Icons.event_outlined,
          label: 'closes_on'.tr(
            namedArgs: {
              'date': DateFormat.yMMMEd(locale).format(survey.deadline),
            },
          ),
        ),
      ],
      onDone: () => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomNavigation(initialIndex: 2),
        ),
        (route) => false,
      ),
    );
  }
}
