import 'package:echomeet/survey_pages/create_survey/question_editor.dart';
import 'package:echomeet/survey_pages/utilities/survey_scoring.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('minimum questions', () {
    test('is two', () {
      expect(kMinimumQuestions, 2);
    });
  });

  group('pass mark', () {
    Map<String, dynamic> singleChoice(int correct) => {
      'type': 'Single',
      'question': 'q',
      'options': ['a', 'b'],
      'correctAnswer': correct,
    };

    SurveyGrade gradeOf(List<List<dynamic>> answers) => SurveyScorer.grade(
      surveyId: 's',
      questions: [for (var i = 0; i < answers.length; i++) singleChoice(0)],
      answers: {
        for (var i = 0; i < answers.length; i++)
          SurveyScorer.answerKey(i): answers[i],
      },
      textReviews: const {},
    );

    test('exactly on the mark passes', () {
      final grade = gradeOf([
        [0],
        [1],
      ]);
      expect(grade.percentage, 50);
      expect(grade.passed, isTrue);
    });

    test('below the mark does not pass', () {
      final grade = gradeOf([
        [1],
        [1],
        [0],
      ]);
      expect(grade.percentage, closeTo(33.3, 0.1));
      expect(grade.passed, isFalse);
    });

    test('all correct passes', () {
      final grade = gradeOf([
        [0],
        [0],
      ]);
      expect(grade.percentage, 100);
      expect(grade.passed, isTrue);
    });
  });
}
