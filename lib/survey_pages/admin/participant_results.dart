import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/survey_pages/admin/print_pages/print_results.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class ParticipantAnswersPage extends StatefulWidget {
  const ParticipantAnswersPage({
    super.key,
    required this.participant,
    required this.survey,
    required this.userId,
  });

  final Participant participant;
  final Survey survey;
  final String userId;

  @override
  State<ParticipantAnswersPage> createState() => _ParticipantAnswersPageState();
}

class _ParticipantAnswersPageState extends State<ParticipantAnswersPage> {
  final _service = FirebaseSurveyService();

  bool _saving = false;

  bool get _isTest => widget.survey.surveyType != SurveyType.survey;

  SurveyGrade get _grade => SurveyScorer.grade(
    surveyId: widget.survey.id,
    questions: widget.survey.questions,
    answers: widget.participant.surveyAnswers,
    textReviews: widget.participant.textAnswersReviewed,
  );

  Future<void> _review(int questionIndex, bool? verdict) async {
    if (_saving) return;

    final key = '${widget.survey.id}-${SurveyScorer.answerKey(questionIndex)}';
    final reviews = Map<String, bool>.from(
      widget.participant.textAnswersReviewed,
    );
    if (verdict == null) {
      reviews.remove(key);
    } else {
      reviews[key] = verdict;
    }

    final grade = SurveyScorer.grade(
      surveyId: widget.survey.id,
      questions: widget.survey.questions,
      answers: widget.participant.surveyAnswers,
      textReviews: reviews,
    );

    final previous = (
      reviews: widget.participant.textAnswersReviewed,
      score: widget.participant.score,
      correct: widget.participant.totalCorrectAnswers,
    );

    setState(() {
      _saving = true;
      widget.participant.textAnswersReviewed = reviews;
      widget.participant.score = grade.percentage;
      widget.participant.totalCorrectAnswers = grade.correctCount;
    });

    try {
      await _service.updateTextAnswersReviewed(
        widget.survey.id,
        widget.participant.userId,
        reviews,
      );
      await _service.updateScore(
        widget.survey.id,
        widget.participant.userId,
        grade.percentage,
      );
      await _service.updateCorrectAnswersCount(
        widget.survey.id,
        widget.participant.userId,
        grade.correctCount,
      );
      if (mounted) setState(() => _saving = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        widget.participant.textAnswersReviewed = previous.reviews;
        widget.participant.score = previous.score;
        widget.participant.totalCorrectAnswers = previous.correct;
      });
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    }
  }

  void _download() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PDFResults(
          participant: widget.participant,
          survey: widget.survey,
          textQuestionCorrect: widget.participant.textAnswersReviewed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grade = _grade;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.participant.name),
        actions: [
          IconButton(
            tooltip: 'download_results'.tr(),
            onPressed: _download,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          const SizedBox(width: Spacing.xs),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,
          scrollable: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: Spacing.xxl),
            children: [
              const SizedBox(height: Spacing.md),
              if (_isTest) _Summary(grade: grade),
              const SizedBox(height: Spacing.lg),

              for (var i = 0; i < widget.survey.questions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.md),
                  child: _QuestionCard(
                    index: i,
                    question: widget.survey.questions[i],
                    answer:
                        widget.participant.surveyAnswers[SurveyScorer.answerKey(
                          i,
                        )] ??
                        const [],
                    isTest: _isTest,
                    verdict: widget
                        .participant
                        .textAnswersReviewed['${widget.survey.id}-${SurveyScorer.answerKey(i)}'],
                    busy: _saving,
                    onReview: (verdict) => _review(i, verdict),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.grade});

  final SurveyGrade grade;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;
    final tone = grade.passed ? app.success : theme.colorScheme.error;

    return ContentCard(
      accent: tone,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '${grade.percentage.round()}%',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: tone,
              height: 1,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                  const SizedBox(height: 2),
                  Text(
                    'awaiting_review'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: app.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          StatusPill(
            label: grade.passed ? 'passed'.tr() : 'not_passed'.tr(),
            tone: grade.passed ? StatusTone.positive : StatusTone.danger,
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.answer,
    required this.isTest,
    required this.verdict,
    required this.busy,
    required this.onReview,
  });

  final int index;
  final Map<String, dynamic> question;
  final List<dynamic> answer;
  final bool isTest;

  final bool? verdict;

  final bool busy;
  final ValueChanged<bool?> onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = QuestionType.parse(question['type']);

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 26,
                child: Text(
                  '${index + 1}.',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  (question['question'] as String? ?? '').trim(),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Padding(
            padding: const EdgeInsets.only(left: 26),
            child: type == QuestionType.text
                ? _TextAnswer(
                    answer: answer,
                    isTest: isTest,
                    verdict: verdict,
                    busy: busy,
                    onReview: onReview,
                  )
                : _Options(question: question, answer: answer, isTest: isTest),
          ),
        ],
      ),
    );
  }
}

class _Options extends StatelessWidget {
  const _Options({
    required this.question,
    required this.answer,
    required this.isTest,
  });

  final Map<String, dynamic> question;
  final List<dynamic> answer;
  final bool isTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;
    final type = QuestionType.parse(question['type']);

    final options = (question['options'] as List<dynamic>? ?? const [])
        .map((option) => '$option')
        .toList();

    final correct = <int>{
      if (type == QuestionType.single && question['correctAnswer'] is int)
        question['correctAnswer'] as int,
      if (type == QuestionType.multiple)
        ...(question['correctAnswers'] as List<dynamic>? ?? const [])
            .whereType<int>(),
    };

    final graded = isTest && correct.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < options.length; i++)
          () {
            final picked = answer.contains(i);
            final isRight = correct.contains(i);

            final (color, icon, label, tone, lostMark) = switch ((
              graded,
              picked,
              isRight,
            )) {
              (true, true, true) => (
                app.success,
                Icons.check_circle_rounded,
                'chosen_correct',
                StatusTone.positive,
                false,
              ),
              (true, true, false) => (
                scheme.error,
                Icons.cancel_rounded,
                'chosen_wrong',
                StatusTone.danger,
                true,
              ),

              (true, false, true) => (
                app.success,
                Icons.check_circle_outline_rounded,
                'missed',
                StatusTone.danger,
                true,
              ),
              (false, true, _) => (
                scheme.primary,
                Icons.radio_button_checked_rounded,
                'chosen',
                StatusTone.info,
                false,
              ),
              _ => (
                scheme.outline,
                Icons.radio_button_unchecked_rounded,
                null,
                StatusTone.neutral,
                false,
              ),
            };

            final border = lostMark ? scheme.error : color;

            return Container(
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: picked
                    ? color.withValues(alpha: 0.12)
                    : Colors.transparent,
                border: Border.all(
                  color: border.withValues(
                    alpha: picked || lostMark ? 0.65 : 0.18,
                  ),
                  width: picked || lostMark ? 1.5 : 1,
                ),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      width: 4,
                      color: picked ? color : Colors.transparent,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.md,
                          vertical: Spacing.sm,
                        ),
                        child: Row(
                          children: [
                            Icon(icon, size: 20, color: color),
                            const SizedBox(width: Spacing.md),
                            Expanded(
                              child: Text(
                                options[i],
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: picked
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (label != null) ...[
                              const SizedBox(width: Spacing.sm),
                              StatusPill(label: label.tr(), tone: tone),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }(),
        if (answer.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xs),
            child: Text(
              'no_answer_given'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({
    required this.answer,
    required this.isTest,
    required this.verdict,
    required this.busy,
    required this.onReview,
  });

  final List<dynamic> answer;
  final bool isTest;
  final bool? verdict;
  final bool busy;
  final ValueChanged<bool?> onReview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;
    final written = answer.join(', ').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Text(
            written.isEmpty ? 'no_answer_given'.tr() : written,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: written.isEmpty ? scheme.onSurfaceVariant : null,
              fontStyle: written.isEmpty ? FontStyle.italic : null,
            ),
          ),
        ),

        if (isTest && written.isNotEmpty) ...[
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  switch (verdict) {
                    true => 'marked_correct'.tr(),
                    false => 'marked_incorrect'.tr(),
                    null => 'awaiting_review'.tr(),
                  },
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: switch (verdict) {
                      true => app.success,
                      false => scheme.error,
                      null => app.warning,
                    },
                  ),
                ),
              ),

              SegmentedButton<bool?>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                segments: [
                  ButtonSegment(
                    value: false,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    tooltip: 'marked_incorrect'.tr(),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    tooltip: 'marked_correct'.tr(),
                  ),
                ],
                selected: {verdict},
                emptySelectionAllowed: true,
                onSelectionChanged: busy
                    ? null
                    : (selection) {
                        final picked = selection.firstOrNull;
                        onReview(picked == verdict ? null : picked);
                      },
              ),
            ],
          ),
        ],
      ],
    );
  }
}
