// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:uuid/uuid.dart';

// enum SurveyType {
//   survey,
//   test,
// }

// class Survey {
//   String surveyName;
//   String surveyDescription;
//   DateTime timeCreated;
//   final List<Map<String, dynamic>> questions;
//   final List<dynamic> correctAnswers;
//   DateTime deadline;
//   String id;
//   List<Participant> participants;
//   int timeLimitPerQuestion;
//   SurveyType surveyType;
//   String companyId;

//   Survey({
//     required this.surveyName,
//     required this.surveyDescription,
//     required this.timeCreated,
//     required this.questions,
//     required this.correctAnswers,
//     required this.id,
//     required this.deadline,
//     required this.participants,
//     this.timeLimitPerQuestion = 0,
//     this.surveyType = SurveyType.survey,
//     required this.companyId,
//   });

//   factory Survey.create({
//     required String title,
//     required String description,
//     required List<Map<String, dynamic>> questions,
//     required List<dynamic> correctAnswers,
//     required List<dynamic> participantsData,
//   }) {
//     final String uniqueId = const Uuid().v4();

//     List<Participant> participants = participantsData.map((participantData) {
//       int participantCorrectAnswers = 0;
//       Map<String, List<dynamic>> participantSurveyAnswers =
//           participantData['surveyAnswers'];

//       for (int i = 0; i < correctAnswers.length; i++) {
//         if (participantSurveyAnswers['question$i'].toString() ==
//             correctAnswers[i].toString()) {
//           participantCorrectAnswers++;
//         }
//       }

//       double participantScore =
//           participantCorrectAnswers / questions.length * 100;

//       return Participant(
//         id: participantData['id'],
//         name: participantData['name'],
//         surveyAnswers: participantSurveyAnswers,
//         score: participantScore,
//       );
//     }).toList();

//     return Survey(
//       surveyName: title,
//       surveyDescription: description,
//       timeCreated: DateTime.now(),
//       questions: questions,
//       correctAnswers: correctAnswers,
//       id: uniqueId,
//       participants: participants,
//       deadline: DateTime.now().add(
//         const Duration(days: 7),
//       ),
//       companyId: '',
//     );
//   }
//   Map<String, dynamic> toFirestoreMap() {
//     return {
//       'surveyName': surveyName,
//       'surveyDescription': surveyDescription,
//       'timeCreated': Timestamp.fromDate(timeCreated),
//       'questions': questions,
//       'correctAnswers': correctAnswers,
//       'id': id,
//       'deadline': Timestamp.fromDate(deadline),
//       'participants': participants
//           .map((participant) => participant.toFirestoreMap())
//           .toList(),
//       'timeLimitPerQuestion': timeLimitPerQuestion,
//       'surveyType': surveyType.index,
//       'companyId': companyId,
//     };
//   }

//   factory Survey.fromFirestore(Map<String, dynamic> data) {
//     List<Map<String, dynamic>> questions = [];
//     if (data['questions'] != null) {
//       questions = (data['questions'] as List)
//           .map((question) => question as Map<String, dynamic>)
//           .toList();
//     }

//     List<Participant> participants = [];
//     if (data['participants'] != null) {
//       participants = (data['participants'] as List)
//           .map((participantData) => Participant.fromFirestore(
//               participantData as Map<String, dynamic>))
//           .toList();
//     }

//     int surveyTypeIndex = data['surveyType'] ?? 0; // Default to 0 if null
//     SurveyType surveyType = SurveyType.values[surveyTypeIndex];

//     return Survey(
//       surveyName: data['surveyName'],
//       surveyDescription: data['surveyDescription'],
//       timeCreated: (data['timeCreated'] as Timestamp).toDate(),
//       questions: questions,
//       correctAnswers: List<dynamic>.from(data['correctAnswers'] ?? []),
//       id: data['id'],
//       deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
//       participants: participants,
//       timeLimitPerQuestion: data['timeLimitPerQuestion'] ?? 0,
//       surveyType: surveyType,
//       companyId: data['companyId'] ?? '',
//       // Use the converted enum value
//     );
//   }
// }

// class Participant {
//   final String id;
//   String name;
//   Map<String, List<dynamic>> surveyAnswers;
//   double score;
//   String textAnswer;
//   bool participantSubmitted = false;
//   String imageProfile;

//   Participant({
//     required this.id,
//     required this.name,
//     required this.surveyAnswers,
//     required this.score,
//     this.textAnswer = '',
//     this.participantSubmitted = false,
//     this.imageProfile = '',
//   });

//   toFirestoreMap() {
//     return {
//       'id': id,
//       'name': name,
//       'surveyAnswers': surveyAnswers,
//       'score': score,
//       'textAnswer': textAnswer,
//       'participantSubmitted': participantSubmitted,
//       'imageProfile': imageProfile,
//     };
//   }

//   factory Participant.fromFirestore(Map<String, dynamic> data) {
//     return Participant(
//       id: data['id'] ?? '',
//       name: data['name'] ?? '',
//       surveyAnswers: Map<String, List<dynamic>>.from(data['answers']),
//       score: (data['score'] as num?)?.toDouble() ?? 0.0,
//       textAnswer: data['textAnswer'] as String? ?? '',
//       participantSubmitted: data['participantSubmitted'] as bool? ?? false,
//       imageProfile: data['imageProfile'] as String? ?? '',
//     );
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum SurveyType {
  survey,
  test,
}

class Survey {
  String surveyName;
  String surveyDescription;
  DateTime timeCreated;
  final List<Map<String, dynamic>> questions;
  DateTime deadline;
  String id;
  List<Participant> participants;
  int timeLimitPerQuestion;
  SurveyType surveyType;
  String companyId;

  Survey({
    required this.surveyName,
    required this.surveyDescription,
    required this.timeCreated,
    required this.questions,
    required this.id,
    required this.deadline,
    required this.participants,
    this.timeLimitPerQuestion = 0,
    this.surveyType = SurveyType.survey,
    required this.companyId,
  });

  factory Survey.create({
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
        userId: participantData['userId'],
        name: participantData['name'],
        surveyAnswers: participantSurveyAnswers,
        score: participantScore,
      );
    }).toList();

    return Survey(
      surveyName: title,
      surveyDescription: description,
      timeCreated: DateTime.now(),
      questions: questions,
      id: uniqueId,
      participants: participants,
      deadline: DateTime.now().add(
        const Duration(days: 7),
      ),
      companyId: '',
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'surveyName': surveyName,
      'surveyDescription': surveyDescription,
      'timeCreated': Timestamp.fromDate(timeCreated),
      'questions': questions,
      'id': id,
      'deadline': Timestamp.fromDate(deadline),
      'participants': participants
          .map((participant) => participant.toFirestoreMap())
          .toList(),
      'timeLimitPerQuestion': timeLimitPerQuestion,
      'surveyType': surveyType.index,
      'companyId': companyId,
    };
  }

  factory Survey.fromFirestore(Map<String, dynamic> data) {
    List<Map<String, dynamic>> questions = [];
    if (data['questions'] != null) {
      questions = (data['questions'] as List)
          .map((question) => question as Map<String, dynamic>)
          .toList();
    }

    List<Participant> participants = [];
    if (data['participants'] != null) {
      participants = (data['participants'] as List)
          .map((participantData) => Participant.fromFirestore(
              participantData as Map<String, dynamic>))
          .toList();
    }

    int surveyTypeIndex = data['surveyType'] ?? 0;
    SurveyType surveyType = SurveyType.values[surveyTypeIndex];

    return Survey(
      surveyName: data['surveyName'],
      surveyDescription: data['surveyDescription'],
      timeCreated: (data['timeCreated'] as Timestamp).toDate(),
      questions: questions,
      id: data['id'],
      deadline: (data['deadline'] as Timestamp?)?.toDate() ?? DateTime.now(),
      participants: participants,
      timeLimitPerQuestion: data['timeLimitPerQuestion'] ?? 0,
      surveyType: surveyType,
      companyId: data['companyId'] ?? '',
    );
  }
}

class Participant {
  final String userId;
  String name;
  Map<String, List<dynamic>> surveyAnswers;
  double score;
  String textAnswer;
  bool participantSubmitted;
  String imageProfile;
  Map<String, bool> textAnswersReviewed;
  int totalCorrectAnswers;
  List<Map<String, dynamic>> participations;

  Participant({
    required this.userId,
    required this.name,
    required this.surveyAnswers,
    required this.score,
    this.textAnswer = '',
    this.participantSubmitted = false,
    this.imageProfile = '',
    this.textAnswersReviewed = const {},
    this.totalCorrectAnswers = 0,
    this.participations = const [],
  });

  toFirestoreMap() {
    return {
      'userId': userId,
      'name': name,
      'surveyAnswers': surveyAnswers,
      'score': score,
      'textAnswer': textAnswer,
      'participantSubmitted': participantSubmitted,
      'imageProfile': imageProfile,
      'textAnswersReviewed': textAnswersReviewed,
      "totalCorrectAnswers": totalCorrectAnswers,
      'participations': participations,
    };
  }

  factory Participant.fromFirestore(Map<String, dynamic> data) {
    return Participant(
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      surveyAnswers: Map<String, List<dynamic>>.from(data['answers']),
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      textAnswer: data['textAnswer'] as String? ?? '',
      participantSubmitted: data['participantSubmitted'] as bool? ?? false,
      imageProfile: data['imageProfile'] as String? ?? '',
      textAnswersReviewed:
          Map<String, bool>.from(data['textAnswersReviewed'] ?? {}),
      totalCorrectAnswers: data['totalCorrectAnswers'] ?? 0,
      participations:
          List<Map<String, dynamic>>.from(data['participations'] ?? []),
    );
  }
}
