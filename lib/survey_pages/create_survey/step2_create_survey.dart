import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/create_survey/step3_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter/material.dart';

class Step2CreateSurvey extends StatefulWidget {
  const Step2CreateSurvey({
    super.key,
    required this.survey,
    required this.onSurveyCreated,
  });

  final Survey survey;
  final ValueChanged<Survey> onSurveyCreated;

  @override
  State<Step2CreateSurvey> createState() => Step2CreateSurveyState();
}

class Step2CreateSurveyState extends State<Step2CreateSurvey> {
  static const _limits = [0, 15, 30, 45, 60, 120];

  late SurveyType _type = widget.survey.surveyType;
  late DateTime _deadline = widget.survey.deadline;
  late int _limit = widget.survey.timeLimitPerQuestion;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline.isBefore(now) ? now : _deadline,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;

    setState(() {
      _deadline = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  void _next() {
    widget.survey
      ..surveyType = _type
      ..deadline = _deadline
      ..timeLimitPerQuestion = _limit;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTrainingSurveyStep3(survey: widget.survey),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTest = _type == SurveyType.test;

    return WizardScaffold(
      step: 2,
      totalSteps: 3,
      appBarTitle: 'create_survey'.tr(),
      title: 'create_survey_step2_title'.tr(),
      subtitle: 'create_survey_step2_subhead'.tr(),
      primaryLabel: 'next'.tr(),
      onPrimary: _next,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TypeChoice(
            selected: _type,
            onChanged: (type) => setState(() => _type = type),
          ),
          const SizedBox(height: Spacing.xl),
          Text('deadline'.tr(), style: theme.textTheme.titleMedium),
          const SizedBox(height: Spacing.md),
          ContentCard(
            onTap: _pickDeadline,
            accent: theme.colorScheme.primary,
            child: Row(
              children: [
                Icon(
                  Icons.event_rounded,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: Spacing.md),
                Expanded(
                  child: Text(
                    DateFormat.yMMMMEEEEd().format(_deadline),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.xl),
          Text(
            'time_limit_per_question'.tr(),
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            isTest ? 'time_limit_hint'.tr() : 'time_limit_survey_hint'.tr(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            children: [
              for (final seconds in _limits)
                ChoiceChip(
                  label: Text(
                    seconds == 0
                        ? 'no_time_limit'.tr()
                        : 'seconds_short'.tr(namedArgs: {'s': '$seconds'}),
                  ),
                  selected: _limit == seconds,
                  onSelected: (_) => setState(() => _limit = seconds),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChoice extends StatelessWidget {
  const _TypeChoice({required this.selected, required this.onChanged});

  final SurveyType selected;
  final ValueChanged<SurveyType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (type, icon, titleKey, bodyKey) in const [
          (
            SurveyType.survey,
            Icons.poll_outlined,
            'standart_survey',
            'survey_type_survey_body',
          ),
          (
            SurveyType.test,
            Icons.workspace_premium_outlined,
            'testing_survey',
            'survey_type_test_body',
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: _TypeCard(
              icon: icon,
              title: titleKey.tr(),
              body: bodyKey.tr(),
              selected: selected == type,
              onTap: () => onChanged(type),
            ),
          ),
      ],
    );
  }
}

class _TypeCard extends StatelessWidget {
  const _TypeCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            color: selected
                ? scheme.primary.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.8),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
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
              SizedBox(
                width: 22,
                child: selected
                    ? Icon(
                        Icons.check_circle_rounded,
                        size: 19,
                        color: scheme.primary,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
