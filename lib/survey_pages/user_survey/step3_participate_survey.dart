import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:echomeet/utilities/bottom_navigation.dart';
import 'package:flutter/material.dart';

class Step3ParticipateSurvey extends StatefulWidget {
  const Step3ParticipateSurvey({
    super.key,
    required this.participant,
    required this.survey,
  });

  final Participant participant;
  final Survey survey;

  @override
  State<Step3ParticipateSurvey> createState() => _Step3ParticipateSurveyState();
}

class _Step3ParticipateSurveyState extends State<Step3ParticipateSurvey> {
  late final Stream<Participant?> _participantStream;

  @override
  void initState() {
    super.initState();
    _participantStream = FirebaseSurveyService().watchParticipant(
      widget.survey.id,
      widget.participant.userId,
    );
  }

  bool get _isTest => widget.survey.surveyType != SurveyType.survey;

  SurveyGrade _grade(Participant participant) =>
      SurveyScorer.authoritativeGrade(
        surveyId: widget.survey.id,
        questions: widget.survey.questions,
        answers: participant.surveyAnswers,
        score: participant.score,
        correctCount: participant.totalCorrectAnswers,
        gradedCount: participant.gradedQuestionCount,
        gradingStatus: participant.gradingStatus,
        textReviews: participant.textAnswersReviewed,
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Participant?>(
      stream: _participantStream,
      initialData: widget.participant,
      builder: (context, snapshot) {
        final participant = snapshot.data ?? widget.participant;
        return _buildPage(context, participant);
      },
    );
  }

  Widget _buildPage(BuildContext context, Participant participant) {
    final theme = Theme.of(context);
    final grade = _isTest ? _grade(participant) : null;

    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xxl),
              _Mark(grade: grade),
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
    final tone = grade.isProcessing
        ? app.info
        : grade.hasPendingReview
        ? app.warning
        : grade.hasGradingError
        ? theme.colorScheme.error
        : grade.passed
        ? app.success
        : theme.colorScheme.error;
    final statusLabel = grade.isProcessing
        ? 'grading_processing'.tr()
        : grade.hasPendingReview
        ? 'awaiting_review'.tr()
        : grade.hasGradingError
        ? 'grading_error'.tr()
        : grade.passed
        ? 'passed'.tr()
        : 'not_passed'.tr();
    final statusTone = grade.isProcessing
        ? StatusTone.info
        : grade.hasPendingReview
        ? StatusTone.caution
        : grade.hasGradingError
        ? StatusTone.danger
        : grade.passed
        ? StatusTone.positive
        : StatusTone.danger;
    final statusBodyKey = grade.isProcessing
        ? 'grading_processing_body'
        : grade.hasPendingReview
        ? 'score_pending_review'
        : grade.hasGradingError
        ? 'grading_error_body'
        : null;

    return ContentCard(
      accent: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                grade.scoreAvailable ? '${grade.percentage.round()}%' : '—',

                style: theme.textTheme.titleLarge?.copyWith(
                  color: tone,
                  height: 1,
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: StatusPill(label: statusLabel, tone: statusTone),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          if (grade.scoreAvailable)
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
          if (statusBodyKey case final statusBodyKey?) ...[
            const SizedBox(height: Spacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  grade.hasGradingError
                      ? Icons.error_outline_rounded
                      : Icons.hourglass_bottom_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: Spacing.sm),

                Expanded(
                  child: Text(
                    statusBodyKey.tr(),
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
  const _Mark({required this.grade});

  final SurveyGrade? grade;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final app = context.appColors;

    final (color, icon) = grade == null
        ? (scheme.primary, Icons.check_rounded)
        : grade!.isProcessing
        ? (app.info, Icons.hourglass_top_rounded)
        : grade!.hasPendingReview
        ? (app.warning, Icons.hourglass_bottom_rounded)
        : grade!.hasGradingError
        ? (scheme.error, Icons.error_outline_rounded)
        : grade!.passed
        ? (app.success, Icons.check_rounded)
        : (scheme.error, Icons.remove_rounded);

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
