import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> snapshot({Object? reviews, bool includeReviews = true}) {
  return {
    'userId': 'alice',
    'name': 'Alice',
    'answers': <String, List<dynamic>>{
      'Q0': ['answer'],
    },
    'score': 100,
    'totalCorrectAnswers': 1,
    'gradedQuestionCount': 1,
    'gradingStatus': 'final',
    if (includeReviews) 'textAnswersReviewed': reviews,
  };
}

SurveyGrade grade(Participant participant) => SurveyScorer.authoritativeGrade(
  surveyId: 'survey-1',
  questions: const [
    {'type': 'Text', 'question': 'Explain'},
  ],
  answers: participant.surveyAnswers,
  score: participant.score,
  correctCount: participant.totalCorrectAnswers,
  gradedCount: participant.gradedQuestionCount,
  gradingStatus: participant.gradingStatus,
  textReviews: participant.textAnswersReviewed,
);

void main() {
  test('valid, absent and null review maps decode without changing status', () {
    final valid = Participant.fromFirestore(
      snapshot(reviews: {'survey-1-Q0': true}),
    );
    final absent = Participant.fromFirestore(snapshot(includeReviews: false));
    final nullReviews = Participant.fromFirestore(snapshot(reviews: null));

    expect(valid.textAnswersReviewed, {'survey-1-Q0': true});
    expect(valid.gradingStatus, 'final');
    expect(absent.textAnswersReviewed, isEmpty);
    expect(absent.gradingStatus, 'final');
    expect(nullReviews.textAnswersReviewed, isEmpty);
    expect(nullReviews.gradingStatus, 'final');
  });

  test(
    'every malformed review shape fails closed for only that participant',
    () {
      final malformed = <Object>[
        'not-a-map',
        {'survey-1-Q0': 'true'},
        <Object, Object>{1: true},
        {for (var index = 0; index < 101; index++) 'survey-1-Q$index': true},
      ];

      for (final raw in malformed) {
        final participant = Participant.fromFirestore(snapshot(reviews: raw));
        expect(participant.textAnswersReviewed, isEmpty);
        expect(participant.gradingStatus, 'error');
        expect(grade(participant).scoreAvailable, isFalse);
        expect(grade(participant).passed, isFalse);
      }
    },
  );

  test('one malformed snapshot does not drop an unaffected participant', () {
    final participants = [
      snapshot(reviews: {'survey-1-Q0': true}),
      snapshot(reviews: {'survey-1-Q0': false, 'poison': 1})
        ..['userId'] = 'bob'
        ..['name'] = 'Bob',
    ].map(Participant.fromFirestore).toList();

    expect(participants, hasLength(2));
    expect(participants.first.textAnswersReviewed, {'survey-1-Q0': true});
    expect(grade(participants.first).resultIsFinal, isTrue);
    expect(participants.last.userId, 'bob');
    expect(participants.last.textAnswersReviewed, isEmpty);
    expect(grade(participants.last).hasGradingError, isTrue);
  });
}
