import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/survey_pages/admin/print_pages/print_analytics.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<List<int>> countAnswers(
  List<Map<String, dynamic>> questions,
  List<Participant> participants,
) {
  final counts = [
    for (final question in questions)
      List.filled(
        ((question['options'] as List<dynamic>?) ?? const []).length,
        0,
      ),
  ];

  for (final participant in participants) {
    for (var i = 0; i < questions.length; i++) {
      final answer = participant.surveyAnswers[SurveyScorer.answerKey(i)];
      if (answer == null) continue;

      for (final option in answer) {
        if (option is int && option >= 0 && option < counts[i].length) {
          counts[i][option]++;
        }
      }
    }
  }

  return counts;
}

class SurveyAnalyticsPage extends StatefulWidget {
  const SurveyAnalyticsPage({
    super.key,
    required this.survey,
    required this.participants,
  });

  final Survey survey;
  final List<Participant> participants;

  @override
  SurveyAnalyticsPageState createState() => SurveyAnalyticsPageState();
}

class SurveyAnalyticsPageState extends State<SurveyAnalyticsPage> {
  final _searchController = TextEditingController();

  late final List<List<int>> _counts = countAnswers(
    widget.survey.questions,
    widget.participants,
  );

  @override
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final participants =
        context.watch<SurveyDataProvider>().participants ?? widget.participants;
    final questions = widget.survey.questions;
    final responded = participants.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.survey.surveyName, overflow: TextOverflow.ellipsis),
        actions: [
          if (participants.isNotEmpty)
            IconButton(
              tooltip: 'pdf_print'.tr(),
              icon: const Icon(Icons.ios_share_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PDFAnalytics(
                    survey: widget.survey,
                    participants: participants,
                    answerCounts: _counts,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: participants.isEmpty
            ? EmptyState(
                icon: Icons.insights_outlined,
                title: 'no_participants_added_yet'.tr(),
                body: 'no_responses_body'.tr(),
              )
            : PageBody(
                maxWidth: 720,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenHeader(
                      title: 'analytics_off'.tr(),
                      subtitle: 'responses_count'.tr(
                        namedArgs: {'count': '$responded'},
                      ),
                    ),
                    const SizedBox(height: Spacing.lg),
                    for (var i = 0; i < questions.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Spacing.md),
                        child: _QuestionBreakdown(
                          index: i,
                          question: questions[i],
                          counts: _counts[i],
                          responded: responded,
                        ),
                      ),
                    _Respondents(
                      participants: participants,
                      controller: _searchController,
                    ),
                    const SizedBox(height: Spacing.xxl),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Respondents extends StatelessWidget {
  const _Respondents({required this.participants, required this.controller});

  final List<Participant> participants;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = controller.text.trim().toLowerCase();
    final names =
        participants
            .map((participant) => participant.name.trim())
            .where((name) => name.isNotEmpty)
            .toList()
          ..sort();
    final matching = query.isEmpty
        ? names
        : names.where((name) => name.toLowerCase().contains(query)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: Spacing.lg),
        SectionLabel(label: 'who_responded'.tr(), count: names.length),
        Padding(
          padding: const EdgeInsets.only(bottom: Spacing.sm),
          child: SearchPill(
            controller: controller,
            hint: 'search_participants'.tr(),
          ),
        ),
        if (matching.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
            child: Text(
              'no_search_results'.tr(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final name in matching)
                MetaChip(icon: Icons.check_rounded, label: name),
            ],
          ),
      ],
    );
  }
}

class _QuestionBreakdown extends StatelessWidget {
  const _QuestionBreakdown({
    required this.index,
    required this.question,
    required this.counts,
    required this.responded,
  });

  final int index;
  final Map<String, dynamic> question;
  final List<int> counts;
  final int responded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final type = QuestionType.parse(question['type']);
    final options = ((question['options'] as List<dynamic>?) ?? const [])
        .map((option) => '$option')
        .toList();

    final best = counts.isEmpty ? 0 : counts.reduce((a, b) => a > b ? a : b);

    return ContentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${'survey_question'.tr()} ${index + 1}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            question['question'] as String? ?? '',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: Spacing.md),
          if (type == QuestionType.text)
            Text(
              'text_answers_not_counted'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (var i = 0; i < options.length; i++)
              _OptionBar(
                label: options[i],
                count: i < counts.length ? counts[i] : 0,
                total: responded,
                leading: best > 0 && i < counts.length && counts[i] == best,
              ),
        ],
      ),
    );
  }
}

class _OptionBar extends StatelessWidget {
  const _OptionBar({
    required this.label,
    required this.count,
    required this.total,
    required this.leading,
  });

  final String label;
  final int count;
  final int total;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = total == 0 ? 0.0 : count / total;
    final colour = leading ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Text(
                '$count · ${(share * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(color: colour),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: share.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                leading ? scheme.primary : scheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
