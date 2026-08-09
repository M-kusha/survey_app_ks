import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/theme/app_theme.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter/material.dart';

const int kMinimumQuestions = 2;

class QuestionProblem {
  const QuestionProblem(this.index, this.messageKey);

  final int index;
  final String messageKey;
}

List<QuestionProblem> validateQuestions(
  List<Map<String, dynamic>> questions, {
  required bool isTest,
}) {
  final problems = <QuestionProblem>[];

  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final type = QuestionType.parse(question['type']);
    final text = (question['question'] as String? ?? '').trim();
    final options = (question['options'] as List<dynamic>? ?? const [])
        .map((answer) => '$answer'.trim())
        .toList();

    if (text.isEmpty) {
      problems.add(QuestionProblem(i, 'question_empty_warning'));
      continue;
    }

    if (type == QuestionType.unknown) {
      problems.add(QuestionProblem(i, 'unsupported_question_type'));
      continue;
    }

    if (type == QuestionType.single || type == QuestionType.multiple) {
      if (options.length < 2) {
        problems.add(QuestionProblem(i, 'needs_two_options'));
        continue;
      }

      if (options.any((option) => option.isEmpty)) {
        problems.add(QuestionProblem(i, 'blank_option'));
        continue;
      }

      final normalized = options.map((option) => option.toLowerCase()).toSet();
      if (normalized.length != options.length) {
        problems.add(QuestionProblem(i, 'duplicate_options'));
        continue;
      }
    }

    if (!isTest) continue;

    switch (type) {
      case QuestionType.single:
        final correct = question['correctAnswer'];
        if (correct is! int || correct < 0 || correct >= options.length) {
          problems.add(QuestionProblem(i, 'single_choice_validation_warning'));
        }
      case QuestionType.multiple:
        final correct = (question['correctAnswers'] as List<dynamic>?) ?? [];
        final validIndexes = correct.whereType<int>().toSet();
        if (validIndexes.length < 2 ||
            validIndexes.length != correct.length ||
            validIndexes.any((index) => index < 0 || index >= options.length)) {
          problems.add(
            QuestionProblem(i, 'multiple_choice_validation_warning'),
          );
        }
      case QuestionType.text:
        break;
      case QuestionType.unknown:
        throw StateError('Unknown question types are rejected above.');
    }
  }

  return problems;
}

class QuestionEditor extends StatelessWidget {
  const QuestionEditor({
    super.key,
    required this.index,
    required this.question,
    required this.isTest,
    required this.onChanged,
    required this.onRemove,
    this.problem,
  });

  final int index;
  final Map<String, dynamic> question;

  final bool isTest;

  final VoidCallback onChanged;
  final VoidCallback onRemove;

  final String? problem;

  QuestionType get _type => QuestionType.parse(question['type']);

  List<String> get _options =>
      ((question['options'] as List<dynamic>?) ?? []).map((a) => '$a').toList();

  void _setOptions(List<String> options) {
    question['options'] = options;
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContentCard(
      accent: problem == null ? null : scheme.error,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(child: _TypeBadge(type: _type)),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  '${'survey_question'.tr()} ${index + 1}',
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'delete'.tr(),
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          TextFormField(
            initialValue: question['question'] as String? ?? '',
            maxLines: null,
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'question_hint'.tr(),
              isDense: true,
            ),
            onChanged: (value) {
              question['question'] = value;
              onChanged();
            },
          ),
          if (_type == QuestionType.single || _type == QuestionType.multiple)
            _Options(
              options: _options,
              type: _type,
              isTest: isTest,
              correctSingle: question['correctAnswer'] as int?,
              correctMultiple:
                  ((question['correctAnswers'] as List<dynamic>?) ?? [])
                      .cast<int>(),
              onOptionsChanged: _setOptions,
              onCorrectChanged: (single, multiple) {
                question['correctAnswer'] = single;
                question['correctAnswers'] = multiple;
                onChanged();
              },
            ),
          if (_type == QuestionType.text)
            Padding(
              padding: const EdgeInsets.only(top: Spacing.sm),
              child: Text(
                'text_answer_hint'.tr(),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          if (problem case final problem?) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 15,
                  color: scheme.error,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    problem.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.error,
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

class _Options extends StatelessWidget {
  const _Options({
    required this.options,
    required this.type,
    required this.isTest,
    required this.correctSingle,
    required this.correctMultiple,
    required this.onOptionsChanged,
    required this.onCorrectChanged,
  });

  final List<String> options;
  final QuestionType type;
  final bool isTest;
  final int? correctSingle;
  final List<int> correctMultiple;
  final ValueChanged<List<String>> onOptionsChanged;
  final void Function(int? single, List<int> multiple) onCorrectChanged;

  bool _isCorrect(int index) => type == QuestionType.single
      ? correctSingle == index
      : correctMultiple.contains(index);

  void _toggleCorrect(int index) {
    if (type == QuestionType.single) {
      onCorrectChanged(correctSingle == index ? null : index, const []);
      return;
    }

    final next = [...correctMultiple];
    next.contains(index) ? next.remove(index) : next.add(index);
    onCorrectChanged(null, next..sort());
  }

  void _remove(int index) {
    final next = [...options]..removeAt(index);

    final single = switch (correctSingle) {
      null => null,
      final c when c == index => null,
      final c when c > index => c - 1,
      final c => c,
    };
    final multiple = [
      for (final c in correctMultiple)
        if (c != index) (c > index ? c - 1 : c),
    ];

    onOptionsChanged(next);
    onCorrectChanged(single, multiple);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: Spacing.sm),
        for (var i = 0; i < options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.sm),
            child: Row(
              children: [
                if (isTest)
                  IconButton(
                    tooltip: 'mark_correct'.tr(),
                    icon: Icon(
                      _isCorrect(i)
                          ? (type == QuestionType.single
                                ? Icons.radio_button_checked_rounded
                                : Icons.check_box_rounded)
                          : (type == QuestionType.single
                                ? Icons.radio_button_unchecked_rounded
                                : Icons.check_box_outline_blank_rounded),
                      size: 20,
                      color: _isCorrect(i)
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    onPressed: () => _toggleCorrect(i),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      String.fromCharCode(65 + i),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextFormField(
                    initialValue: options[i],
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'option_hint'.tr(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      final next = [...options];
                      next[i] = value;
                      onOptionsChanged(next);
                    },
                  ),
                ),
                IconButton(
                  tooltip: 'delete'.tr(),
                  icon: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => _remove(i),
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () => onOptionsChanged([...options, '']),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text('add_option'.tr()),
        ),
      ],
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final QuestionType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, labelKey) = switch (type) {
      QuestionType.single => (
        Icons.radio_button_checked_rounded,
        'single_choice',
      ),
      QuestionType.multiple => (Icons.checklist_rounded, 'multiple_choice'),
      QuestionType.text => (Icons.notes_rounded, 'text_answer'),
      QuestionType.unknown => (Icons.help_outline_rounded, 'unknown'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.full),
        color: scheme.primary.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: scheme.primary),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              labelKey.tr(),
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
