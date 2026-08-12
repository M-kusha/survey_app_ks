import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _membersSubscription;
  Map<String, ({String storedReference, int revision})> _memberAvatars =
      const {};
  int _memberGeneration = 0;

  @override
  void initState() {
    super.initState();
    _watchMemberAvatars(widget.survey.companyId);
  }

  @override
  void didUpdateWidget(covariant SurveyParticipantsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.survey.companyId != widget.survey.companyId) {
      _watchMemberAvatars(widget.survey.companyId);
    }
  }

  void _watchMemberAvatars(String companyId) {
    final generation = ++_memberGeneration;
    final previousSubscription = _membersSubscription;
    _membersSubscription = null;
    unawaited(previousSubscription?.cancel());
    _memberAvatars = const {};

    final id = companyId.trim();
    if (id.isEmpty) return;
    _membersSubscription = FirebaseFirestore.instance
        .collection('memberDirectory')
        .where('companyId', isEqualTo: id)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || generation != _memberGeneration) return;
            final avatars =
                <String, ({String storedReference, int revision})>{};
            for (final document in snapshot.docs) {
              final data = document.data();
              final storedReference = data['profileImage'];
              if (storedReference is! String ||
                  storedReference.trim().isEmpty) {
                continue;
              }
              avatars[document.id] = (
                storedReference: storedReference.trim(),
                revision: readProfileImageRevision(
                  data['profileImageRevision'],
                ),
              );
            }
            setState(() => _memberAvatars = avatars);
          },
          onError: (Object _) {
            // Historical participant snapshots remain the read-only fallback.
          },
        );
  }

  @override
  void dispose() {
    ++_memberGeneration;
    unawaited(_membersSubscription?.cancel());
    super.dispose();
  }

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
                ParticipantsSummary(survey: widget.survey, participants: participants),
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
      itemBuilder: (context, index) {
        final participant = participants[index];
        final currentAvatar = _memberAvatars[participant.userId];
        return _ParticipantRow(
          survey: widget.survey,
          participant: participant,
          avatarStoredReference:
              currentAvatar?.storedReference ?? participant.imageProfile,
          avatarRevision:
              currentAvatar?.revision ?? participant.profileImageRevision,
          rank: index + 1,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ParticipantAnswersPage(
                participant: participant,
                survey: widget.survey,

                userId: participant.userId,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How a test went, at a glance: the average, the pass split, and any
/// exceptions that actually occurred.
class ParticipantsSummary extends StatelessWidget {
  const ParticipantsSummary({
    super.key,
    required this.survey,
    required this.participants,
  });

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

    // Six figures used to be laid out in a fixed three-by-two grid whether or
    // not they had anything to report, so a healthy test showed one number and
    // five zeros under labels like "grading errors". The average is the figure
    // that always means something; the rest are exceptions, and an exception
    // worth a place on screen is one that actually happened.
    final band = average == null ? null : ScoreBand.of(average);
    final averageColour = band == null
        ? theme.colorScheme.onSurfaceVariant
        : _colourFor(context, band);

    final exceptions = <({String label, int count, Color colour})>[
      if (pending > 0)
        (label: 'awaiting_review'.tr(), count: pending, colour: app.warning),
      if (processing > 0)
        (label: 'grading_processing'.tr(), count: processing, colour: app.info),
      if (errors > 0)
        (
          label: 'grading_errors'.tr(),
          count: errors,
          colour: theme.colorScheme.error,
        ),
    ];

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'average'.tr().toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      average == null ? '—' : '${average.round()}%',
                      // Same size as every other score in the app, so a figure
                      // reads as a figure wherever it appears.
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: averageColour,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              // Nothing has finished grading yet, so a pass split would be two
              // more zeros. The average already reads "—"; the exceptions below
              // say what is actually happening.
              if (passed + failed > 0) ...[
                _Tally(
                  count: passed,
                  label: 'passed'.tr(),
                  colour: app.success,
                ),
                const SizedBox(width: Spacing.lg),
                _Tally(
                  count: failed,
                  label: 'not_passed'.tr(),
                  colour: theme.colorScheme.error,
                ),
              ],
            ],
          ),
          if (passed + failed > 0) ...[
            const SizedBox(height: Spacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: SizedBox(
                height: 5,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (passed > 0)
                      Expanded(flex: passed, child: ColoredBox(color: app.success)),
                    if (failed > 0)
                      Expanded(
                        flex: failed,
                        child: ColoredBox(color: theme.colorScheme.error),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (exceptions.isNotEmpty) ...[
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.md,
              runSpacing: Spacing.sm,
              children: [
                for (final exception in exceptions)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        height: 7,
                        width: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: exception.colour,
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        '${exception.count} ${exception.label}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
              ],
            ),
          ],
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


/// A count with its label beneath, sized to sit beside the average rather than
/// compete with it.
class _Tally extends StatelessWidget {
  const _Tally({
    required this.count,
    required this.label,
    required this.colour,
  });

  final int count;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$count',
          style: theme.textTheme.titleMedium?.copyWith(
            color: colour,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
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
    // Six chips were offered unconditionally, so a test with no errors and
    // nothing pending still showed "Grading errors 0" and wrapped onto a second
    // and third row. A filter that would empty the list is not a choice worth
    // offering; "All" always stays, and the current selection stays even if its
    // count has just dropped to zero, so the chips cannot vanish under the tap
    // that selected them.
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
          if (filter == ParticipantFilter.all ||
              selected == filter ||
              (counts[filter] ?? 0) > 0)
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
    required this.avatarStoredReference,
    required this.avatarRevision,
    required this.rank,
    required this.onTap,
  });

  final Survey survey;
  final Participant participant;
  final String avatarStoredReference;
  final int avatarRevision;
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
          _Avatar(
            participant: participant,
            storedReference: avatarStoredReference,
            revision: avatarRevision,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  participant.displayName('unknown'.tr()),
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
  const _Avatar({
    required this.participant,
    required this.storedReference,
    required this.revision,
  });

  final Participant participant;
  final String storedReference;
  final int revision;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final name = participant.displayName('unknown'.tr()).trim();

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
                storedReference: storedReference,
                refreshKey: revision,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
