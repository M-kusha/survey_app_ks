import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';

class FirebaseSurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createSurvey(Survey survey) async {
    final document = _firestore.collection('surveys').doc();
    final uniqueId = document.id;

    Map<String, dynamic> surveyData = {
      'surveyName': survey.surveyName,
      'surveyDescription': survey.surveyDescription,
      'timeCreated': Timestamp.fromDate(survey.timeCreated),
      'questions': survey.questions,
      'id': uniqueId,
      'participants': survey.participants
          .map((e) => e.toFirestoreMap())
          .toList(),
      'deadline': survey.deadline,
      'timeLimitPerQuestion': survey.timeLimitPerQuestion,
      'surveyType': survey.surveyType.index,
      'companyId': survey.companyId,

      'createdBy': FirebaseAuth.instance.currentUser?.uid,
    };

    await document.set(surveyData);
    return uniqueId;
  }

  Future<void> deleteSurvey(String surveyId) async {
    final survey = _firestore.collection('surveys').doc(surveyId);
    final responses = await survey.collection('participants').get();

    const chunkSize = 400;
    for (var start = 0; start < responses.docs.length; start += chunkSize) {
      final batch = _firestore.batch();
      final end = (start + chunkSize).clamp(0, responses.docs.length);
      for (final doc in responses.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await survey.delete();
  }

  Future<void> removeUserFromCompany(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'companyId': '',
      'role': 'user',
    });
  }

  Future<void> updateTextAnswersReviewed(
    String surveyId,
    String participantId,
    Map<String, bool> textAnswersReviewed,
  ) async {
    await _firestore
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .doc(participantId)
        .update({'textAnswersReviewed': textAnswersReviewed});
  }

  Future<void> updateCorrectAnswersCount(
    String surveyId,
    String participantId,
    int correctAnswersCount,
  ) async {
    await _firestore
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .doc(participantId)
        .update({'totalCorrectAnswers': correctAnswersCount});
  }

  Future<void> updateScore(
    String surveyId,
    String participantId,
    double newScore,
  ) async {
    await _firestore
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .doc(participantId)
        .update({'score': newScore});
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
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': newRole,
    });
  }
}
