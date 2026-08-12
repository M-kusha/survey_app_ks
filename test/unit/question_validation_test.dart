import 'package:echomeet/survey_pages/create_survey/question_editor.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> single({
  String text = 'Pick one',
  List<String> options = const ['A', 'B'],
  int? correct,
}) => {
  'type': 'Single',
  'question': text,
  'options': options,
  'correctAnswer': correct,
};

Map<String, dynamic> multiple({
  String text = 'Pick some',
  List<String> options = const ['A', 'B', 'C'],
  List<int> correct = const [],
}) => {
  'type': 'Multiple',
  'question': text,
  'options': options,
  'correctAnswers': correct,
};

Map<String, dynamic> text({String question = 'Say something'}) => {
  'type': 'Text',
  'question': question,
};

List<String> keys(List<QuestionProblem> problems) =>
    problems.map((p) => p.messageKey).toList();

void main() {
  group('as a survey — no right answers required', () {
    test('a choice question with options is fine', () {
      expect(validateQuestions([single()], isTest: false), isEmpty);
    });

    test('no correct answer is not a problem', () {
      final problems = validateQuestions([
        single(correct: null),
        multiple(correct: const []),
      ], isTest: false);
      expect(problems, isEmpty);
    });

    test('a blank question is still a problem', () {
      expect(keys(validateQuestions([single(text: '   ')], isTest: false)), [
        'question_empty_warning',
      ]);
    });

    test('fewer than two options is a problem', () {
      expect(
        keys(
          validateQuestions([
            single(options: ['only one']),
          ], isTest: false),
        ),
        ['needs_two_options'],
      );
    });

    test('blank options do not count towards the two', () {
      expect(
        keys(
          validateQuestions([
            single(options: ['A', '  ']),
          ], isTest: false),
        ),
        ['blank_option'],
      );
    });

    test('a blank third option is rejected rather than silently displayed', () {
      expect(
        keys(
          validateQuestions([
            single(options: ['A', 'B', '   ']),
          ], isTest: false),
        ),
        ['blank_option'],
      );
    });

    test('duplicate options are rejected after trimming and case folding', () {
      expect(
        keys(
          validateQuestions([
            single(options: ['Yes', ' yes ']),
          ], isTest: false),
        ),
        ['duplicate_options'],
      );
    });
  });

  group('as a test — right answers required', () {
    test('single choice needs one marked', () {
      expect(keys(validateQuestions([single(correct: null)], isTest: true)), [
        'single_choice_validation_warning',
      ]);
      expect(validateQuestions([single(correct: 0)], isTest: true), isEmpty);
    });

    test('single choice rejects an out-of-range answer index', () {
      expect(keys(validateQuestions([single(correct: 2)], isTest: true)), [
        'single_choice_validation_warning',
      ]);
    });

    test('multiple choice needs at least two marked', () {
      expect(
        keys(
          validateQuestions([
            multiple(correct: const [0]),
          ], isTest: true),
        ),
        ['multiple_choice_validation_warning'],
      );
      expect(
        validateQuestions([
          multiple(correct: const [0, 2]),
        ], isTest: true),
        isEmpty,
      );
    });

    test('multiple choice rejects duplicate and out-of-range indexes', () {
      expect(
        keys(
          validateQuestions([
            multiple(correct: const [0, 0]),
            multiple(correct: const [0, 3]),
          ], isTest: true),
        ),
        [
          'multiple_choice_validation_warning',
          'multiple_choice_validation_warning',
        ],
      );
    });

    test('a text question needs no marking, even in a test', () {
      expect(validateQuestions([text()], isTest: true), isEmpty);
    });
  });

  group('reporting', () {
    test('every broken question is named, not just the first', () {
      final problems = validateQuestions([
        single(correct: 0),
        single(text: ''),
        multiple(correct: const []),
      ], isTest: true);

      expect(problems, hasLength(2));
      expect(problems.map((p) => p.index), [1, 2]);
    });

    test('one problem per question, the first that applies', () {
      final problems = validateQuestions([
        single(text: '', options: const []),
      ], isTest: true);
      expect(keys(problems), ['question_empty_warning']);
    });

    test('an empty survey has nothing wrong with it', () {
      expect(validateQuestions([], isTest: true), isEmpty);
    });

    test('a question of an unrecognised type is rejected without throwing', () {
      final problems = validateQuestions([
        {'type': 'Ranking', 'question': 'From the future'},
      ], isTest: true);
      expect(keys(problems), ['unsupported_question_type']);
    });
  });
}
