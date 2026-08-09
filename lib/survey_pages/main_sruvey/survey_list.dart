import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/time/deadline.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/status_pill.dart';
import 'package:echomeet/survey_pages/admin/survey_analytics.dart';
import 'package:echomeet/survey_pages/admin/survey_participants.dart';
import 'package:echomeet/survey_pages/user_survey/step1_participate_survey.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurveyListItem extends StatelessWidget {
  const SurveyListItem({
    super.key,
    required this.survey,
    required this.isAdmin,
    required this.hasParticipated,
    this.onChanged,
    this.now,
  });

  final Survey survey;
  final bool isAdmin;
  final bool hasParticipated;

  final VoidCallback? onChanged;

  final DateTime? now;

  bool _canParticipate(Deadline deadline) =>
      !deadline.isPassed && !hasParticipated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    final deadline = deadlineFor(
      survey.deadline,
      now: now ?? DateTime.now(),
      openedAt: survey.timeCreated,
    );
    final open = _canParticipate(deadline);

    final isTest = survey.surveyType == SurveyType.test;

    final (statusKey, tone, icon, accent) = switch (this) {
      _ when deadline.isPassed => (
        'expired',
        StatusTone.neutral,
        Icons.lock_outline_rounded,
        scheme.outline,
      ),
      _ when hasParticipated => (
        'already_participated',
        StatusTone.positive,
        Icons.check_rounded,
        app.success,
      ),

      _ when deadline.urgency == DeadlineUrgency.imminent => (
        deadline.labelKey,
        StatusTone.caution,
        Icons.bolt_rounded,
        app.warning,
      ),
      _ => (
        'open_status',
        StatusTone.info,
        Icons.edit_outlined,
        scheme.primary,
      ),
    };

    return ContentCard(
      onTap: open ? () => _openSurvey(context) : null,
      muted: !open,
      accent: accent,
      progress: deadline.progress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TypeGlyph(isTest: isTest, tint: accent),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (isTest ? 'label_test' : 'label_survey').tr(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      survey.surveyName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (isAdmin) ...[
                const SizedBox(width: Spacing.sm),
                _AdminButton(survey: survey, onChanged: onChanged),
              ],
            ],
          ),
          const SizedBox(height: Spacing.md),

          Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: statusKey.tr(namedArgs: {'count': '${deadline.days}'}),
                tone: tone,
                icon: icon,
              ),
              MetaChip(
                icon: Icons.help_outline_rounded,
                label: 'question_count'.tr(
                  namedArgs: {'count': '${survey.questions.length}'},
                ),
              ),
              MetaChip(
                icon: Icons.event_outlined,

                label: (deadline.isPassed ? 'closed_on' : 'closes_on').tr(
                  namedArgs: {
                    'date': DateFormat.MMMEd().format(survey.deadline),
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openSurvey(BuildContext context) {
    final user = Provider.of<UserDataProvider>(
      context,
      listen: false,
    ).currentUser;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Step1ParticipateSurvey(
          survey: survey,
          participant: Participant(
            name: user?.name ?? 'Guest',
            userId: user?.id ?? '',
            surveyAnswers: {},
            score: 0,
            textAnswersReviewed: {},
          ),
          imageProfile: user?.profileImage ?? '',
        ),
      ),
    );
  }
}

class _AdminButton extends StatelessWidget {
  const _AdminButton({required this.survey, required this.onChanged});

  final Survey survey;

  final VoidCallback? onChanged;

  Future<void> _open(BuildContext context) async {
    final provider = Provider.of<SurveyDataProvider>(context, listen: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const CustomLoadingWidget(loadingText: 'loading'),
    );

    await provider.loadParticipants(survey.id);
    if (!context.mounted) return;

    Navigator.pop(context);

    final participants = provider.participants;
    if (participants == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => survey.surveyType == SurveyType.survey
            ? SurveyAnalyticsPage(survey: survey, participants: participants)
            : SurveyParticipantsPage(
                survey: survey,
                participants: participants,
                surveyId: survey.id,
              ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final provider = Provider.of<SurveyDataProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    await provider.loadParticipants(survey.id);
    if (!context.mounted) return;
    final responses = provider.participants?.length ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('delete_survey'.tr()),
        content: Text(
          'delete_survey_confirm'.tr(
            namedArgs: {'name': survey.surveyName, 'count': '$responses'},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('delete'.tr()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseSurveyService().deleteSurvey(survey.id);
      messenger.showSnackBar(SnackBar(content: Text('survey_deleted'.tr())));
      onChanged?.call();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PopupMenuButton<void Function()>(
      tooltip: 'manage'.tr(),
      onSelected: (action) => action(),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: () => _open(context),
          child: Row(
            children: [
              const Icon(Icons.insights_rounded, size: 18),
              const SizedBox(width: Spacing.md),
              Text('view_results'.tr()),
            ],
          ),
        ),
        PopupMenuItem(
          value: () => _delete(context),
          child: Row(
            children: [
              Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
              const SizedBox(width: Spacing.md),
              Text('delete_survey'.tr(), style: TextStyle(color: scheme.error)),
            ],
          ),
        ),
      ],
      child: CircleAction(
        icon: Icons.more_horiz_rounded,
        tooltip: 'manage'.tr(),
        onTap: null,
      ),
    );
  }
}

class _TypeGlyph extends StatelessWidget {
  const _TypeGlyph({required this.isTest, required this.tint});

  final bool isTest;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.md),
        color: tint.withValues(alpha: 0.12),
        border: Border.all(color: tint.withValues(alpha: 0.28)),
      ),
      child: Icon(
        isTest ? Icons.workspace_premium_outlined : Icons.poll_outlined,
        size: 20,
        color: tint,
      ),
    );
  }
}
