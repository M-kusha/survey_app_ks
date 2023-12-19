import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

class SurveyQuestionaryType {
  String surveyName;
  String surveyDescription;
  DateTime timeCreated;
  List<Map<String, dynamic>> questions;
  List<dynamic> correctAnswers;
  DateTime? deadline;
  String id;
  List<Participant> participants;

  SurveyQuestionaryType({
    required this.surveyName,
    required this.surveyDescription,
    required this.timeCreated,
    required this.questions,
    required this.correctAnswers,
    required this.id,
    this.deadline,
    required this.participants,
  });

  factory SurveyQuestionaryType.create({
    required String title,
    required String description,
    required List<Map<String, dynamic>> questions,
    required List<dynamic> correctAnswers,
    required List<dynamic> participantsData,
  }) {
    final String uniqueId = const Uuid().v4();

    List<Participant> participants = participantsData.map((participantData) {
      int participantCorrectAnswers = 0;
      Map<String, List<dynamic>> participantSurveyAnswers =
          participantData['surveyAnswers'];

      for (int i = 0; i < correctAnswers.length; i++) {
        if (participantSurveyAnswers['question$i'].toString() ==
            correctAnswers[i].toString()) {
          participantCorrectAnswers++;
        }
      }

      double participantScore =
          participantCorrectAnswers / questions.length * 100;

      return Participant(
        id: participantData['id'],
        name: participantData['name'],
        surveyAnswers: participantSurveyAnswers,
        correctAnswers: participantCorrectAnswers,
        score: participantScore,
      );
    }).toList();

    return SurveyQuestionaryType(
      surveyName: title,
      surveyDescription: description,
      timeCreated: DateTime.now(),
      questions: questions,
      correctAnswers: correctAnswers,
      id: uniqueId,
      participants: participants,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'surveyName': surveyName,
      'surveyDescription': surveyDescription,
      'timeCreated': timeCreated.toIso8601String(),
      'questions': questions,
      'correctAnswers': correctAnswers,
      'id': id,
      'participants': participants.map((p) => p.toFirestore()).toList(),
      'deadline': deadline!.toIso8601String(),
    };
  }

  static SurveyQuestionaryType fromFirestore(Map<String, dynamic> map) {
    return SurveyQuestionaryType(
      surveyName: map['surveyName'],
      surveyDescription: map['surveyDescription'],
      timeCreated: DateTime.parse(map['timeCreated']),
      questions: List<Map<String, dynamic>>.from(map['questions']),
      correctAnswers: List<dynamic>.from(map['correctAnswers']),
      id: map['id'],
      participants: List<Participant>.from(
          map['participants'].map((p) => Participant.fromFirestore(p))),
      deadline: DateTime.parse(map['deadline']),
    );
  }
}

class Participant {
  final String id;
  String name;
  Map<String, List<dynamic>> surveyAnswers;
  int correctAnswers;
  double score;
  String textAnswer;

  Participant({
    required this.id,
    required this.name,
    required this.surveyAnswers,
    required this.correctAnswers,
    required this.score,
    this.textAnswer = '',
  });

  static Participant fromFirestore(Map<String, dynamic> map) {
    return Participant(
      id: map['id'],
      name: map['name'],
      surveyAnswers: Map<String, List<dynamic>>.from(map['surveyAnswers']),
      correctAnswers: map['correctAnswers'],
      score: map['score'],
      textAnswer: map['textAnswer'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'surveyAnswers': surveyAnswers,
      'correctAnswers': correctAnswers,
      'score': score,
      'textAnswer': textAnswer,
    };
  }
}

Future<SurveyQuestionaryType> fetchSurvey(String surveyId) async {
  var docSnapshot = await FirebaseFirestore.instance
      .collection('questionary')
      .doc(surveyId)
      .get();

  if (docSnapshot.exists) {
    return SurveyQuestionaryType.fromFirestore(docSnapshot.data()!);
  } else {
    throw Exception('Survey not found');
  }
}
