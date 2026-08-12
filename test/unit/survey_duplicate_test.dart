import 'package:echomeet/survey_pages/utilities/survey_duplicate.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _single(String text, List<String> options) => {
  'type': 'Single',
  'question': text,
  'options': options,
};

Map<String, dynamic> _multiple(String text, List<String> options) => {
  'type': 'Multiple',
  'question': text,
  'options': options,
};

Map<String, dynamic> _text(String text) => {'type': 'Text', 'question': text};

void main() {
  group('questions', () {
    test('a test question gets its marked answer back', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [
          _single('Capital of France?', ['Paris', 'Rome']),
        ],
        correctIndexes: [
          {0},
        ],
      );

      expect(rebuilt.single['type'], 'Single');
      expect(rebuilt.single['question'], 'Capital of France?');
      expect(rebuilt.single['options'], ['Paris', 'Rome']);
      expect(rebuilt.single['correctAnswer'], 0);
    });

    test('a multiple-choice question keeps every marked answer, sorted', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [
          _multiple('Pick two', ['a', 'b', 'c']),
        ],
        correctIndexes: [
          {2, 0},
        ],
      );

      expect(rebuilt.single['correctAnswers'], [0, 2]);
    });

    test('a plain survey copies with nothing marked', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [
          _single('Favourite colour?', ['red', 'blue']),
        ],
        correctIndexes: const [],
      );

      expect(rebuilt.single.containsKey('correctAnswer'), isFalse);
      expect(rebuilt.single['options'], ['red', 'blue']);
    });

    test('a text question carries no options and no key', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [_text('Tell us more')],
        correctIndexes: [
          {0},
        ],
      );

      expect(rebuilt.single.keys.toSet(), {'type', 'question'});
    });

    test('two answers marked on a single-choice question mark neither', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [
          _single('Only one', ['a', 'b']),
        ],
        correctIndexes: [
          {0, 1},
        ],
      );

      expect(rebuilt.single.containsKey('correctAnswer'), isFalse);
    });

    test('an index pointing past the options is dropped', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [
          _single('Two options', ['a', 'b']),
          _multiple('Also two', ['a', 'b']),
        ],
        correctIndexes: [
          {7},
          {1, 9},
        ],
      );

      expect(rebuilt.first.containsKey('correctAnswer'), isFalse);
      expect(rebuilt.last['correctAnswers'], [1]);
    });

    test('a malformed question is skipped rather than copied broken', () {
      final rebuilt = duplicateSurveyQuestions(
        questions: [
          {'type': 'Single'},
          _single('Real one', ['a', 'b']),
        ],
        correctIndexes: const [],
      );

      expect(rebuilt, hasLength(1));
      expect(rebuilt.single['question'], 'Real one');
    });

    test('editing the copy cannot reach back into the original', () {
      final options = ['a', 'b'];
      final source = [_single('Question', options)];

      final rebuilt = duplicateSurveyQuestions(
        questions: source,
        correctIndexes: const [],
      );
      (rebuilt.single['options'] as List).add('c');

      expect(options, ['a', 'b']);
      expect(source.single['options'], ['a', 'b']);
    });
  });

  group('template', () {
    Survey source() => Survey(
      surveyName: 'Original',
      surveyDescription: 'Why we ask',
      timeCreated: DateTime(2026, 1, 1),
      questions: [
        _single('Q', ['a', 'b']),
      ],
      id: 'original-id',
      deadline: DateTime(2026, 2, 1),
      participants: [
        Participant(
          userId: 'someone',
          name: 'Someone',
          surveyAnswers: const {},
          score: 0,
        ),
      ],
      timeLimitPerQuestion: 45,
      surveyType: SurveyType.test,
      companyId: 'company',
    );

    test('carries the settings that make it the same kind of survey', () {
      final copy = duplicateSurveyTemplate(
        source: source(),
        correctIndexes: [
          {1},
        ],
        name: 'Original (copy)',
        newId: 'new-id',
        deadline: DateTime(2026, 9, 1),
      );

      expect(copy.surveyName, 'Original (copy)');
      expect(copy.surveyDescription, 'Why we ask');
      expect(copy.surveyType, SurveyType.test);
      expect(copy.timeLimitPerQuestion, 45);
      expect(copy.questions.single['correctAnswer'], 1);
    });

    test('carries nothing that identified the original', () {
      final copy = duplicateSurveyTemplate(
        source: source(),
        correctIndexes: const [],
        name: 'copy',
        newId: 'new-id',
        deadline: DateTime(2026, 9, 1),
      );

      expect(copy.id, 'new-id');
      expect(copy.participants, isEmpty);

      expect(copy.companyId, '');
    });

    test('never inherits the deadline, so a closed survey copies open', () {
      final closed = source()..deadline = DateTime(2020, 1, 1);
      final fresh = DateTime(2026, 9, 1);

      final copy = duplicateSurveyTemplate(
        source: closed,
        correctIndexes: const [],
        name: 'copy',
        newId: 'new-id',
        deadline: fresh,
      );

      expect(copy.deadline, fresh);
    });
  });
}
