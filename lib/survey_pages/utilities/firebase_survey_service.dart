import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';
import 'package:uuid/uuid.dart';

class FirebaseSurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createSurvey(Survey survey) async {
    String uniqueId = const Uuid().v1().substring(0, 6);
    Map<String, dynamic> surveyData = {
      'surveyName': survey.surveyName,
      'surveyDescription': survey.surveyDescription,
      'timeCreated': Timestamp.fromDate(survey.timeCreated),
      'questions': survey.questions,
      'id': uniqueId,
      'participants':
          survey.participants.map((e) => e.toFirestoreMap()).toList(),
      'deadline': survey.deadline,
      'timeLimitPerQuestion': survey.timeLimitPerQuestion,
      'surveyType': survey.surveyType.index,
      'companyId': survey.companyId,
    };

    await _firestore.collection('surveys').doc(uniqueId).set(surveyData);
    return uniqueId;
  }

  Future<String?> fetchCurrentUserCompanyId() async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return null;

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    var data = userDoc.data();
    if (data is Map<String, dynamic>) {
      return data['companyId'] as String?;
    }
    return null;
  }

  Future<void> updateTextAnswersReviewed(String surveyId, String participantId,
      Map<String, bool> textAnswersReviewed) async {
    await _firestore
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .doc(participantId)
        .update({'textAnswersReviewed': textAnswersReviewed});
  }

  updateCorrectAnswersCount(
      String surveyId, String participantId, int correctAnswersCount) {
    FirebaseFirestore.instance
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .doc(participantId)
        .update({'totalCorrectAnswers': correctAnswersCount})
        .then((_) {})
        .catchError((error) {});
  }

  updateScore(String surveyId, String participantId, double newScore) {
    FirebaseFirestore.instance
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .doc(participantId)
        .update({'score': newScore})
        .then((_) {})
        .catchError((error) {});
  }

  Future<void> submitSurveyAnswers({
    required String surveyId,
    required Participant participant,
    required Map<String, List<dynamic>> answers,
    required double score,
    required String imageProfile,
    required Map<String, bool> textAnswersReviewed,
    required int totalCorrectAnswers,
  }) async {
    try {
      await _firestore
          .collection('surveys')
          .doc(surveyId)
          .collection('participants')
          .doc(participant.userId)
          .set({
        'userId': participant.userId,
        'name': participant.name,
        'answers': answers,
        'score': score,
        'submittedAt': FieldValue.serverTimestamp(),
        'participantSubmitted': true,
        'imageProfile': imageProfile,
        'textAnswersReviewed': textAnswersReviewed,
        'totalCorrectAnswers': totalCorrectAnswers,
      });
    } catch (e) {
      throw Exception('Error saving answers: $e');
    }
  }

  Future<QuerySnapshot> fetchUsersByCompanyId(String companyId) {
    return FirebaseFirestore.instance
        .collection('users')
        .where('companyId', isEqualTo: companyId)
        .get();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .update({'role': newRole});
  }
}
