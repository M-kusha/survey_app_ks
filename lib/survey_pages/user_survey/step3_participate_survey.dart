import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';

class Step3ParticipateSurvey extends StatelessWidget {
  const Step3ParticipateSurvey({
    super.key,
    required this.participant,
    required this.survey,
  });

  final Participant participant;
  final Survey survey;

  bool get _isTest => survey.surveyType != SurveyType.survey;

  SurveyGrade get _grade => SurveyScorer.grade(
    surveyId: survey.id,
    questions: survey.questions,
    answers: participant.surveyAnswers,
    textReviews: participant.textAnswersReviewed,
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = _isTest ? _grade : null;

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xxl),
              _Mark(passed: grade?.passed),
              const SizedBox(height: Spacing.xl),
              Text(
                _isTest ? 'test_finished'.tr() : 'thank_you'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                _isTest
                    ? 'test_finished_message'.tr()
                    : 'survey_finished_message'.tr(),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (grade case final grade?) ...[
                const SizedBox(height: Spacing.xl),
                _ScoreCard(grade: grade),
              ],
              const SizedBox(height: Spacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: WizardActionBar(
        maxWidth: 520,
        child: FilledButton(
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const BottomNavigation(initialIndex: 2),
            ),
            (route) => false,
          ),
          child: Text('back_to_surveys'.tr()),
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.grade});

  final SurveyGrade grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;
    final tone = grade.passed ? app.success : theme.colorScheme.error;

    return ContentCard(
      accent: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${grade.percentage.round()}%',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tone,
                  height: 1,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusPill(
                    label: grade.passed ? 'passed'.tr() : 'not_passed'.tr(),
                    tone: grade.passed
                        ? StatusTone.positive
                        : StatusTone.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          Text(
            'correct_of_total'.tr(
              namedArgs: {
                'correct': '${grade.correctCount}',
                'total': '${grade.gradedCount}',
              },
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (grade.hasPendingReview) ...[
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),

                Expanded(
                  child: Text(
                    'score_pending_review'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.passed});

  final bool? passed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.appColors;

    final (color, icon) = switch (passed) {
      null => (scheme.primary, Icons.check_rounded),
      true => (app.success, Icons.check_rounded),
      false => (scheme.error, Icons.remove_rounded),
    };

    return Center(
      child: Container(
        height: 72,
        width: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 34, color: color),
      ),
    );
  }
}
