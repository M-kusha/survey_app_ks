import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/membership/member_directory.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:echomeet/survey_pages/utilities/survey_answer_keys.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';

class FirebaseSurveyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createSurvey(Survey survey) async {
    final document = _firestore.collection('surveys').doc();
    final uniqueId = document.id;
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) throw StateError('A signed-in author is required.');

    final questions = splitSurveyQuestions(survey.questions);

    Map<String, dynamic> surveyData = {
      'surveyName': survey.surveyName,
      'surveyDescription': survey.surveyDescription,
      'timeCreated': Timestamp.fromDate(survey.timeCreated),
      'questions': questions.publicQuestions,
      'id': uniqueId,
      'participants': survey.participants
          .map((e) => e.toFirestoreMap())
          .toList(),
      'deadline': survey.deadline,
      'timeLimitPerQuestion': survey.timeLimitPerQuestion,
      'surveyType': survey.surveyType.index,
      'companyId': survey.companyId,

      'createdBy': userId,
    };

    final answerKey = _firestore.collection('surveyAnswerKeys').doc(uniqueId);
    final batch = _firestore.batch();
    batch.set(document, surveyData);
    batch.set(answerKey, {
      'schemaVersion': 1,
      'surveyId': uniqueId,
      'companyId': survey.companyId,
      'questionKeys': questions.privateAnswerKeys,
    });
    await batch.commit();
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

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('surveyAnswerKeys').doc(surveyId));
    batch.delete(survey);
    await batch.commit();
  }

  Future<void> removeUserFromCompany(String userId) async {
    await MemberDirectory.removeMember(firestore: _firestore, userId: userId);
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

  Stream<Participant?> watchParticipant(
    String surveyId,
    String participantId,
  ) => _firestore
      .collection('surveys')
      .doc(surveyId)
      .collection('participants')
      .doc(participantId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        return snapshot.exists && data != null
            ? Participant.fromFirestore(data)
            : null;
      });

  Future<void> submitSurveyAnswers({
    required String surveyId,
    required Participant participant,
    required Map<String, List<dynamic>> answers,
    required String imageProfile,
  }) async {
    try {
      final directory = await _firestore
          .collection('memberDirectory')
          .doc(participant.userId)
          .get();
      final member = directory.data();
      final currentStoredImage = member?['profileImage'] as String?;
      final resolvedImage = profileImageReference(
        currentStoredImage ?? imageProfile,
      );
      final imagePath =
          resolvedImage?.fullPath == profileImagePathFor(participant.userId)
          ? resolvedImage!.fullPath
          : '';
      final currentRevision = readProfileImageRevision(
        member?['profileImageRevision'],
      );
      final imageRevision = member == null
          ? participant.profileImageRevision
          : currentRevision;
      await _firestore
          .collection('surveys')
          .doc(surveyId)
          .collection('participants')
          .doc(participant.userId)
          .set({
            'userId': participant.userId,
            'name': participant.name,
            'answers': answers,
            // Security rules only accept sentinels on the untrusted first
            // write. A Firestore trigger computes the authoritative grade.
            'score': 0.0,
            'submittedAt': FieldValue.serverTimestamp(),
            'participantSubmitted': true,
            'imageProfile': imagePath,
            'profileImageRevision': imageRevision,
            'textAnswersReviewed': <String, bool>{},
            'totalCorrectAnswers': 0,
            'gradedQuestionCount': 0,
            'gradingStatus': 'processing',
          });
    } catch (e) {
      throw Exception('Error saving answers: $e');
    }
  }

  Future<QuerySnapshot> fetchUsersByCompanyId(String companyId) {
    return FirebaseFirestore.instance
        .collection('memberDirectory')
        .where('companyId', isEqualTo: companyId)
        .get();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await MemberDirectory.updateMember(
      firestore: FirebaseFirestore.instance,
      userId: userId,
      fields: {'role': newRole},
    );
  }
}
