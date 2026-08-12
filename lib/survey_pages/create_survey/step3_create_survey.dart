import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/create_survey/question_editor.dart';
import 'package:echomeet/survey_pages/create_survey/step4_create_survey.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';

class CreateTrainingSurveyStep3 extends StatefulWidget {
  const CreateTrainingSurveyStep3({super.key, required this.survey});

  final Survey survey;

  @override
  State<CreateTrainingSurveyStep3> createState() =>
      _CreateTrainingSurveyStep3State();
}

class _CreateTrainingSurveyStep3State extends State<CreateTrainingSurveyStep3> {
  late final _questions = [...widget.survey.questions];

  bool _saving = false;

  Map<int, String> _problems = {};

  bool get _isTest => widget.survey.surveyType == SurveyType.test;

  void _add(String type) {
    setState(() {
      _questions.add({
        'type': type,
        'question': '',

        if (type != 'Text') 'options': ['', ''],
        if (type == 'Multiple') 'correctAnswers': <int>[],
      });
    });
  }

  void _remove(int index) {
    setState(() {
      _questions.removeAt(index);

      _problems = {};
    });
  }

  Future<void> _finish() async {
    final problems = validateQuestions(_questions, isTest: _isTest);

    if (_questions.length < kMinimumQuestions) {
      UIUtils.showSnackBar(
        context,
        'survey_needs_questions'.tr(namedArgs: {'count': '$kMinimumQuestions'}),
      );
      return;
    }

    if (problems.isNotEmpty) {
      setState(() {
        _problems = {
          for (final problem in problems) problem.index: problem.messageKey,
        };
      });

      UIUtils.showSnackBar(
        context,
        'questions_need_attention'.tr(
          namedArgs: {'count': '${problems.length}'},
        ),
      );
      return;
    }

    setState(() {
      _problems = {};
      _saving = true;
    });

    final survey = Survey(
      surveyName: widget.survey.surveyName,
      surveyDescription: widget.survey.surveyDescription,
      timeCreated: DateTime.now(),
      questions: _questions,
      id: widget.survey.id,
      participants: [],
      deadline: widget.survey.deadline,
      timeLimitPerQuestion: widget.survey.timeLimitPerQuestion,
      surveyType: widget.survey.surveyType,
      companyId: widget.survey.companyId,
    );

    try {
      final companyId = await FirebaseServices().currentCompanyId();

      if (companyId == null) {
        throw StateError('The signed-in user has no companyId.');
      }
      survey.companyId = companyId;

      survey.id = await FirebaseSurveyService().createSurvey(survey);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => Step4CreateSurvey(survey: survey),
        ),
      );
    } on StateError {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'no_company_error'.tr());
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WizardScaffold(
      step: 3,
      totalSteps: 3,
      appBarTitle: 'create_survey'.tr(),
      title: 'create_survey_step3_title'.tr(),
      subtitle: _isTest
          ? 'create_survey_step3_subhead_test'.tr()
          : 'create_survey_step3_subhead'.tr(),
      primaryLabel: 'finish'.tr(),
      busy: _saving,
      onPrimary: _finish,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_isTest) ...[
            _SwitchToTest(
              onSwitch: () => setState(() {
                widget.survey.surveyType = SurveyType.test;
              }),
            ),
            const SizedBox(height: Spacing.md),
          ],
          if (_questions.isEmpty)
            EmptyState(
              icon: Icons.help_outline_rounded,
              title: 'no_questions_yet'.tr(),
              body: 'no_questions_body'.tr(),
            )
          else
            for (var i = 0; i < _questions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.md),
                child: QuestionEditor(
                  key: ValueKey(_questions[i]),
                  index: i,
                  question: _questions[i],
                  isTest: _isTest,
                  problem: _problems[i],
                  onChanged: () => setState(() {}),
                  onRemove: () => _remove(i),
                ),
              ),
          const SizedBox(height: Spacing.sm),

          if (_questions.isNotEmpty && _questions.length < kMinimumQuestions)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      'survey_needs_questions'.tr(
                        namedArgs: {'count': '$kMinimumQuestions'},
                      ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          _AddQuestion(onAdd: _add),
        ],
      ),
    );
  }
}

class _SwitchToTest extends StatelessWidget {
  const _SwitchToTest({required this.onSwitch});

  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Text(
              'not_a_test_hint'.tr(),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(width: Spacing.sm),
          TextButton(onPressed: onSwitch, child: Text('make_it_a_test'.tr())),
        ],
      ),
    );
  }
}

class _AddQuestion extends StatelessWidget {
  const _AddQuestion({required this.onAdd});

  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (type, icon, labelKey) in const [
          ('Single', Icons.radio_button_checked_rounded, 'single_choice'),
          ('Multiple', Icons.checklist_rounded, 'multiple_choice'),
          ('Text', Icons.notes_rounded, 'text_answer'),
        ]) ...[
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => onAdd(type),
              icon: Icon(icon, size: 16),
              label: Text(
                labelKey.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (type != 'Text') const SizedBox(width: Spacing.sm),
        ],
      ],
    );
  }
}
