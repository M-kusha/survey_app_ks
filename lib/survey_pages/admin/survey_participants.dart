import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
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

enum ParticipantFilter { all, passed, failed }

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

  List<Participant> _visible(List<Participant> participants) {
    final result = switch (_filter) {
      ParticipantFilter.all => [...participants],
      ParticipantFilter.passed =>
        participants.where((p) => ScoreBand.of(p.score).isPass).toList(),
      ParticipantFilter.failed =>
        participants.where((p) => !ScoreBand.of(p.score).isPass).toList(),
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
                _Summary(participants: participants),
                const SizedBox(height: Spacing.md),
                _Filters(
                  selected: _filter,
                  counts: {
                    ParticipantFilter.all: participants.length,
                    ParticipantFilter.passed: participants
                        .where((p) => ScoreBand.of(p.score).isPass)
                        .length,
                    ParticipantFilter.failed: participants
                        .where((p) => !ScoreBand.of(p.score).isPass)
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
  const _Summary({required this.participants});

  final List<Participant> participants;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final app = context.appColors;

    if (participants.isEmpty) return const SizedBox.shrink();

    final scores = participants.map((p) => p.score).toList();
    final average = scores.reduce((a, b) => a + b) / scores.length;
    final passed = participants
        .where((p) => ScoreBand.of(p.score).isPass)
        .length;

    return ContentCard(
      child: Row(
        children: [
          _Figure(
            label: 'average'.tr(),
            value: '${average.round()}%',
            color: _colourFor(context, ScoreBand.of(average)),
          ),
          _Divider(),
          _Figure(label: 'passed'.tr(), value: '$passed', color: app.success),
          _Divider(),

          _Figure(
            label: 'not_passed'.tr(),
            value: '${participants.length - passed}',
            color: theme.colorScheme.error,
          ),
          _Divider(),
          _Figure(
            label: 'participants'.tr(),
            value: '${participants.length}',
            color: theme.colorScheme.onSurfaceVariant,
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
    return Row(
      children: [
        for (final (filter, labelKey) in const [
          (ParticipantFilter.all, 'filter_all'),
          (ParticipantFilter.passed, 'passed'),
          (ParticipantFilter.failed, 'failed'),
        ])
          Padding(
            padding: const EdgeInsets.only(right: Spacing.sm),
            child: ChoiceChip(
              label: Text('${labelKey.tr()} ${counts[filter] ?? 0}'),
              selected: selected == filter,
              onSelected: (_) => onChanged(filter),
            ),
          ),
      ],
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.rank,
    required this.onTap,
  });

  final Participant participant;
  final int rank;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final band = ScoreBand.of(participant.score);
    final colour = _colourFor(context, band);

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
                    value: (participant.score / 100).clamp(0.0, 1.0),
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
            '${participant.score.round()}%',
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

    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.primaryContainer,
        image: participant.imageProfile.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(participant.imageProfile),
                fit: BoxFit.cover,
              ),
      ),
      alignment: Alignment.center,
      child: participant.imageProfile.isEmpty
          ? Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            )
          : null,
    );
  }
}
