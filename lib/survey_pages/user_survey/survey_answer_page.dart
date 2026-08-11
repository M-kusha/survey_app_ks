import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/theme/app_colors.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/wizard_scaffold.dart';
import 'package:echomeet/survey_pages/user_survey/step3_participate_survey.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SurveyAnswerPage extends StatefulWidget {
  const SurveyAnswerPage({
    super.key,
    required this.survey,
    required this.participant,
    required this.imageProfile,
  });

  final Survey survey;
  final Participant participant;
  final String imageProfile;

  @override
  State<SurveyAnswerPage> createState() => _SurveyAnswerPageState();
}

class _SurveyAnswerPageState extends State<SurveyAnswerPage> {
  late final List<List<dynamic>> _answers = List.generate(
    widget.survey.questions.length,
    (_) => <dynamic>[],
  );
  late final List<TextEditingController> _textControllers = List.generate(
    widget.survey.questions.length,
    (_) => TextEditingController(),
  );

  final _pageController = PageController();

  int _current = 0;
  int _remaining = 0;
  Timer? _timer;
  bool _submitting = false;
  bool _advancing = false;

  bool get _isTimed => widget.survey.timeLimitPerQuestion > 0;

  int get _answered => _answers.where((answer) => answer.isNotEmpty).length;

  @override
  void initState() {
    super.initState();
    if (_isTimed) _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    for (final controller in _textControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _remaining = widget.survey.timeLimitPerQuestion;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remaining > 1) {
        setState(() => _remaining--);
        return;
      }
      timer.cancel();
      _advance();
    });
  }

  Future<void> _advance() async {
    if (_advancing || _submitting) return;

    if (_current < widget.survey.questions.length - 1) {
      setState(() => _advancing = true);
      try {
        await _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } finally {
        if (mounted) setState(() => _advancing = false);
      }
      return;
    }
    await _submit();
  }

  void _setAnswer(int index, List<dynamic> answer) {
    setState(() => _answers[index] = answer);
  }

  Future<void> _submit() async {
    if (_submitting) return;

    if (!_isTimed && _answered < widget.survey.questions.length) {
      UIUtils.showSnackBar(context, 'please_answer_all_questions'.tr());
      return;
    }

    setState(() => _submitting = true);
    _timer?.cancel();

    final answers = {
      for (var i = 0; i < widget.survey.questions.length; i++)
        SurveyScorer.answerKey(i): _answers[i],
    };

    widget.participant
      ..score = 0
      ..surveyAnswers = answers
      ..participantSubmitted = true
      ..totalCorrectAnswers = 0
      ..gradedQuestionCount = 0
      ..gradingStatus = 'processing';

    try {
      await FirebaseSurveyService().submitSurveyAnswers(
        surveyId: widget.survey.id,
        participant: widget.participant,
        answers: answers,
        imageProfile: widget.imageProfile,
      );
      if (!mounted) return;
      context.read<SurveyDataProvider>().markParticipationSubmitted(
        surveyId: widget.survey.id,
        userId: widget.participant.userId,
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => Step3ParticipateSurvey(
            participant: widget.participant,
            survey: widget.survey,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      UIUtils.showSnackBar(context, 'error_occurred'.tr());
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questions = widget.survey.questions;
    final total = questions.length;

    return PopScope(
      canPop: !_isTimed || _submitting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.survey.surveyName,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              PageBody(
                maxWidth: 640,
                scrollable: false,
                padding: const EdgeInsets.fromLTRB(
                  Spacing.lg,
                  Spacing.md,
                  Spacing.lg,
                  Spacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Progress(
                      step: _isTimed ? _current + 1 : _answered,
                      total: total,
                      remaining: _isTimed ? _remaining : null,
                      limit: widget.survey.timeLimitPerQuestion,
                    ),
                    if (_isTimed) ...[
                      const SizedBox(height: Spacing.xs),
                      Text(
                        'question_timer_ux_only'.tr(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: _isTimed ? _buildTimed(questions) : _buildAll(questions),
              ),
            ],
          ),
        ),
        bottomNavigationBar: WizardActionBar(
          child: FilledButton(
            onPressed: _submitting || _advancing
                ? null
                : (_isTimed ? _advance : _submit),
            child: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _isTimed && _current < total - 1
                        ? 'next'.tr()
                        : 'submit'.tr(),
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('leave_test'.tr()),
        content: Text('leave_test_body'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('keep_going'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('submit'.tr()),
          ),
        ],
      ),
    );

    if (leave != true || !mounted) return;

    await _submit();
  }

  Widget _buildAll(List<Map<String, dynamic>> questions) {
    return PageBody(
      maxWidth: 640,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.survey.surveyDescription.isNotEmpty) ...[
            Text(
              widget.survey.surveyDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.lg),
          ],
          for (var i = 0; i < questions.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.md),
              child: AnswerCard(
                index: i,
                total: questions.length,
                question: questions[i],
                answer: _answers[i],
                textController: _textControllers[i],
                onChanged: (answer) => _setAnswer(i, answer),
              ),
            ),
          const SizedBox(height: Spacing.xxl),
        ],
      ),
    );
  }

  Widget _buildTimed(List<Map<String, dynamic>> questions) {
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,

            physics: const NeverScrollableScrollPhysics(),
            itemCount: questions.length,
            onPageChanged: (index) {
              setState(() => _current = index);
              _startTimer();
            },
            itemBuilder: (context, i) => PageBody(
              maxWidth: 640,
              child: AnswerCard(
                index: i,
                total: questions.length,
                question: questions[i],
                answer: _answers[i],
                textController: _textControllers[i],
                onChanged: (answer) => _setAnswer(i, answer),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({
    required this.step,
    required this.total,
    required this.remaining,
    required this.limit,
  });

  final int step;
  final int total;

  final int? remaining;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final app = context.appColors;

    final left = remaining;
    final running = (left == null || limit == 0) ? 1.0 : left / limit;

    final clock = running > 0.25 ? scheme.onSurfaceVariant : app.warning;

    return Row(
      children: [
        Text(
          'progress_of'.tr(namedArgs: {'current': '$step', 'total': '$total'}),
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: Row(
            children: [
              for (var i = 1; i <= total; i++) ...[
                if (i > 1) const SizedBox(width: 3),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: i <= step
                          ? scheme.primary
                          : scheme.surfaceContainerHighest,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (left != null) ...[
          const SizedBox(width: Spacing.md),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_outlined, size: 14, color: clock),
              const SizedBox(width: 4),
              Text(
                'seconds_short'.tr(namedArgs: {'s': '$left'}),
                style: theme.textTheme.labelMedium?.copyWith(color: clock),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class AnswerCard extends StatelessWidget {
  const AnswerCard({
    super.key,
    required this.index,
    required this.total,
    required this.question,
    required this.answer,
    required this.textController,
    required this.onChanged,
  });

  final int index;
  final int total;
  final Map<String, dynamic> question;
  final List<dynamic> answer;
  final TextEditingController textController;
  final ValueChanged<List<dynamic>> onChanged;

  QuestionType get _type => QuestionType.parse(question['type']);

  List<String> get _options =>
      ((question['options'] as List<dynamic>?) ?? []).map((a) => '$a').toList();

  void _tapOption(int option) {
    if (_type == QuestionType.single) {
      onChanged(answer.contains(option) ? [] : [option]);
      return;
    }

    final next = [...answer];
    next.contains(option) ? next.remove(option) : next.add(option);
    onChanged(next..sort());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final answered = answer.isNotEmpty;

    return ContentCard(
      accent: answered ? context.appColors.success : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1} / $total',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              if (_type == QuestionType.multiple)
                Text(
                  'choose_all_that_apply'.tr(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            question['question'] as String? ?? '',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.md),
          if (_type == QuestionType.text)
            TextField(
              controller: textController,
              maxLines: null,
              minLines: 3,
              decoration: InputDecoration(hintText: 'your_answer'.tr()),
              onChanged: (value) =>
                  onChanged(value.trim().isEmpty ? [] : [value]),
            )
          else
            for (var i = 0; i < _options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Spacing.sm),
                child: _Option(
                  label: _options[i],
                  letter: String.fromCharCode(65 + i),
                  selected: answer.contains(i),
                  multiple: _type == QuestionType.multiple,
                  onTap: () => _tapOption(i),
                ),
              ),
        ],
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.letter,
    required this.selected,
    required this.multiple,
    required this.onTap,
  });

  final String label;
  final String letter;
  final bool selected;
  final bool multiple;
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
        borderRadius: BorderRadius.circular(Radii.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.md),
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                multiple
                    ? (selected
                          ? Icons.check_box_rounded
                          : Icons.check_box_outline_blank_rounded)
                    : (selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded),
                size: 20,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: Spacing.md),
              Text(
                letter,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
