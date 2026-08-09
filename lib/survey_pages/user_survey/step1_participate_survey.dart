import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/user_survey/survey_answer_page.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';

class Step1ParticipateSurvey extends StatefulWidget {
  const Step1ParticipateSurvey({
    super.key,
    required this.survey,
    required this.participant,
    required this.imageProfile,
  });

  final Survey survey;
  final Participant participant;
  final String imageProfile;

  @override
  State<Step1ParticipateSurvey> createState() => _Step1ParticipateSurveyState();
}

class _Step1ParticipateSurveyState extends State<Step1ParticipateSurvey> {
  bool get _isTest => widget.survey.surveyType == SurveyType.test;

  @override
  void initState() {
    super.initState();

    if (!_isTest) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _start(replace: true);
      });
    }
  }

  void _start({bool replace = false}) {
    final route = MaterialPageRoute<void>(
      builder: (context) => SurveyAnswerPage(
        survey: widget.survey,
        participant: widget.participant,
        imageProfile: widget.imageProfile,
      ),
    );

    replace
        ? Navigator.of(context).pushReplacement(route)
        : Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTest) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final theme = Theme.of(context);
    final questions = widget.survey.questions.length;
    final limit = widget.survey.timeLimitPerQuestion;

    return Scaffold(
      appBar: AppBar(title: Text(widget.survey.surveyName)),
      body: SafeArea(
        child: PageBody(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.md),
              Text(
                'before_you_start'.tr(),
                style: theme.textTheme.headlineSmall,
              ),
              if (widget.survey.surveyDescription.isNotEmpty) ...[
                const SizedBox(height: Spacing.sm),
                Text(
                  widget.survey.surveyDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: Spacing.xl),

              _Rule(
                icon: Icons.help_outline_rounded,
                title: 'question_count'.tr(namedArgs: {'count': '$questions'}),
                body: 'rule_answer_all'.tr(),
              ),
              _Rule(
                icon: Icons.timer_outlined,
                title: limit > 0
                    ? 'seconds_per_question'.tr(namedArgs: {'s': '$limit'})
                    : 'no_time_limit'.tr(),
                body: limit > 0 ? 'rule_timed'.tr() : 'rule_untimed'.tr(),
              ),
              _Rule(
                icon: Icons.workspace_premium_outlined,
                title: 'rule_graded_title'.tr(),
                body: 'rule_graded'.tr(),
              ),
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: WizardActionBar(
        child: FilledButton(onPressed: _start, child: Text('start'.tr())),
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.md),
      child: ContentCard(
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.md),
                color: scheme.primary.withValues(alpha: 0.12),
              ),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: Spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
