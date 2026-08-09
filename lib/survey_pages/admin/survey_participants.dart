import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/survey_pages/admin/participant_results.dart';
import 'package:echomeet/survey_pages/admin/print_pages/group_results_pdf.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum ScoreBand {
  strong,
  fair,
  weak;

  static ScoreBand of(double score) => switch (score) {
    >= 75 => ScoreBand.strong,

    >= kPassingPercentage => ScoreBand.fair,
    _ => ScoreBand.weak,
  };

  bool get isPass => this != ScoreBand.weak;
}

enum ParticipantFilter { all, passed, failed, pending, processing, error }

SurveyGrade _authoritativeGrade(Survey survey, Participant participant) =>
    SurveyScorer.authoritativeGrade(
      surveyId: survey.id,
      questions: survey.questions,
      answers: participant.surveyAnswers,
      score: participant.score,
      correctCount: participant.totalCorrectAnswers,
      gradedCount: participant.gradedQuestionCount,
      gradingStatus: participant.gradingStatus,
      textReviews: participant.textAnswersReviewed,
    );

class SurveyParticipantsPage extends StatefulWidget {
  const SurveyParticipantsPage({
    super.key,
    required this.survey,
    required this.participants,
    required this.surveyId,
  });

  final Survey survey;
  final List<Participant> participants;
  final String surveyId;

  @override
  SurveyParticipantsPageState createState() => SurveyParticipantsPageState();
}

class SurveyParticipantsPageState extends State<SurveyParticipantsPage> {
  ParticipantFilter _filter = ParticipantFilter.all;

  SurveyGrade _gradeFor(Participant participant) =>
      _authoritativeGrade(widget.survey, participant);

  bool _isPending(Participant participant) =>
      _gradeFor(participant).hasPendingReview;

  bool _isProcessing(Participant participant) =>
      _gradeFor(participant).isProcessing;

  bool _hasGradingError(Participant participant) =>
      _gradeFor(participant).hasGradingError;

  bool _hasPassed(Participant participant) => _gradeFor(participant).passed;

  bool _hasFailed(Participant participant) {
    final grade = _gradeFor(participant);
    return grade.resultIsFinal && !grade.passed;
  }

  List<Participant> _visible(List<Participant> participants) {
    final result = switch (_filter) {
      ParticipantFilter.all => [...participants],
      ParticipantFilter.passed => participants.where(_hasPassed).toList(),
      ParticipantFilter.failed => participants.where(_hasFailed).toList(),
      ParticipantFilter.pending => participants.where(_isPending).toList(),
      ParticipantFilter.processing =>
        participants.where(_isProcessing).toList(),
      ParticipantFilter.error => participants.where(_hasGradingError).toList(),
    };

    result.sort((a, b) => b.score.compareTo(a.score));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final participants =
        Provider.of<SurveyDataProvider>(context).participants ??
        widget.participants;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.surveyName, overflow: TextOverflow.ellipsis),
        actions: [
          if (widget.survey.surveyType == SurveyType.test &&
              participants.isNotEmpty)
            IconButton(
              tooltip: 'export_results'.tr(),
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GroupResultsPdf(
                    survey: widget.survey,
                    participants: _visible(participants),
                    groupLabel: switch (_filter) {
                      ParticipantFilter.all => 'filter_all'.tr(),
                      ParticipantFilter.passed => 'passed'.tr(),
                      ParticipantFilter.failed => 'not_passed'.tr(),
                      ParticipantFilter.pending => 'awaiting_review'.tr(),
                      ParticipantFilter.processing => 'grading_processing'.tr(),
                      ParticipantFilter.error => 'grading_errors'.tr(),
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,
          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.survey.surveyType == SurveyType.survey)
                Expanded(
                  child: EmptyState(
                    icon: Icons.insights_outlined,
                    title: 'this_page_shows'.tr(),
                  ),
                )
              else ...[
                _Summary(survey: widget.survey, participants: participants),
                const SizedBox(height: Spacing.md),
                _Filters(
                  selected: _filter,
                  counts: {
                    ParticipantFilter.all: participants.length,
                    ParticipantFilter.passed: participants
                        .where(_hasPassed)
                        .length,
                    ParticipantFilter.failed: participants
                        .where(_hasFailed)
                        .length,
                    ParticipantFilter.pending: participants
                        .where(_isPending)
                        .length,
                    ParticipantFilter.processing: participants
                        .where(_isProcessing)
                        .length,
                    ParticipantFilter.error: participants
                        .where(_hasGradingError)
                        .length,
                  },
                  onChanged: (filter) => setState(() => _filter = filter),
                ),
                const SizedBox(height: Spacing.md),
                Expanded(child: _buildList(_visible(participants))),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Participant> participants) {
    if (participants.isEmpty) {
      return EmptyState(
        icon: Icons.person_search_rounded,
        title: _filter == ParticipantFilter.all
            ? 'no_participants_added_yet'.tr()
            : 'no_search_results'.tr(),
        action: _filter == ParticipantFilter.all
            ? null
            : TextButton(
                onPressed: () =>
                    setState(() => _filter = ParticipantFilter.all),
                child: Text('filter_all'.tr()),
              ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: Spacing.xxl),
      itemCount: participants.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (context, index) => _ParticipantRow(
        survey: widget.survey,
        participant: participants[index],
        rank: index + 1,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParticipantAnswersPage(
              participant: participants[index],
              survey: widget.survey,

              userId: participants[index].userId,
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.survey, required this.participants});

  final Survey survey;
  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    if (participants.isEmpty) return const SizedBox.shrink();

    final grades = [
      for (final participant in participants)
        _authoritativeGrade(survey, participant),
    ];
    final finalGrades = grades.where((grade) => grade.resultIsFinal).toList();
    final average = finalGrades.isEmpty
        ? null
        : finalGrades.map((grade) => grade.percentage).reduce((a, b) => a + b) /
              finalGrades.length;
    final passed = finalGrades.where((grade) => grade.passed).length;
    final failed = finalGrades.length - passed;
    final pending = grades.where((grade) => grade.hasPendingReview).length;
    final processing = grades.where((grade) => grade.isProcessing).length;
    final errors = grades.where((grade) => grade.hasGradingError).length;

    return ContentCard(
      child: Column(
        children: [
          Row(
            children: [
              _Figure(
                label: 'average'.tr(),
                value: average == null ? '—' : '${average.round()}%',
                color: average == null
                    ? theme.colorScheme.onSurfaceVariant
                    : _colourFor(context, ScoreBand.of(average)),
              ),
              _Divider(),
              _Figure(
                label: 'passed'.tr(),
                value: '$passed',
                color: app.success,
              ),
              _Divider(),
              _Figure(
                label: 'not_passed'.tr(),
                value: '$failed',
                color: theme.colorScheme.error,
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          Divider(height: 1, color: theme.colorScheme.outlineVariant),
          const SizedBox(height: Spacing.md),
          Row(
            children: [
              _Figure(
                label: 'awaiting_review'.tr(),
                value: '$pending',
                color: app.warning,
              ),
              _Divider(),
              _Figure(
                label: 'grading_processing'.tr(),
                value: '$processing',
                color: app.info,
              ),
              _Divider(),
              _Figure(
                label: 'grading_errors'.tr(),
                value: '$errors',
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _colourFor(BuildContext context, ScoreBand band) {
  final app = context.appColors;
  return switch (band) {
    ScoreBand.strong => app.success,
    ScoreBand.fair => app.warning,
    ScoreBand.weak => Theme.of(context).colorScheme.error,
  };
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 32,
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final ParticipantFilter selected;
  final Map<ParticipantFilter, int> counts;
  final ValueChanged<ParticipantFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: Spacing.sm,
      runSpacing: Spacing.sm,
      children: [
        for (final (filter, labelKey) in const [
          (ParticipantFilter.all, 'filter_all'),
          (ParticipantFilter.passed, 'passed'),
          (ParticipantFilter.failed, 'failed'),
          (ParticipantFilter.pending, 'awaiting_review'),
          (ParticipantFilter.processing, 'grading_processing'),
          (ParticipantFilter.error, 'grading_errors'),
        ])
          ChoiceChip(
            label: Text('${labelKey.tr()} ${counts[filter] ?? 0}'),
            selected: selected == filter,
            onSelected: (_) => onChanged(filter),
          ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.survey,
    required this.participant,
    required this.rank,
    required this.onTap,
  });

  final Survey survey;
  final Participant participant;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final grade = _authoritativeGrade(survey, participant);
    final band = ScoreBand.of(participant.score);
    final colour = grade.isProcessing
        ? context.appColors.info
        : grade.hasPendingReview
        ? context.appColors.warning
        : grade.hasGradingError
        ? scheme.error
        : _colourFor(context, band);
    final resultLabel = grade.isProcessing
        ? 'grading_processing'.tr()
        : grade.hasPendingReview
        ? 'awaiting_review'.tr()
        : grade.hasGradingError
        ? 'grading_error'.tr()
        : '${participant.score.round()}%';

    return ContentCard(
      onTap: onTap,
      accent: colour,
      child: Row(
        children: [
          SizedBox(
            width: 22,
            child: Text(
              '$rank',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          _Avatar(participant: participant),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.name,
                  style: theme.textTheme.bodyLarge,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: grade.resultIsFinal
                        ? (participant.score / 100).clamp(0.0, 1.0)
                        : 0,
                    minHeight: 4,
                    backgroundColor: scheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(colour),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: Spacing.md),
          Text(
            resultLabel,
            style: theme.textTheme.titleSmall?.copyWith(color: colour),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.participant});

  final Participant participant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = participant.name.trim();

    return ClipOval(
      child: SizedBox(
        height: 34,
        width: 34,
        child: ColoredBox(
          color: scheme.primaryContainer,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              AuthenticatedProfileImage(
                storedReference: participant.imageProfile,
                refreshKey: participant.profileImageRevision,
                userId: participant.userId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
