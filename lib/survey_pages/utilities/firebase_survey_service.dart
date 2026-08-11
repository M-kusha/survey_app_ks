import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/membership/member_directory.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'package:echomeet/survey_pages/utilities/survey_answer_keys.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';

class FirebaseSurveyService {
  FirebaseSurveyService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: 'europe-west4');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<String> createSurvey(Survey survey) async {
    final requestedSurveyId = survey.id.trim();
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(requestedSurveyId)) {
      throw ArgumentError('A valid survey id is required.');
    }
    final isTest = survey.surveyType == SurveyType.test;
    final callable = _functions.httpsCallable(
      'saveSurveyDefinition',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final result = await callable.call<Map<String, dynamic>>(
      {
        'action': 'create',
        'surveyId': requestedSurveyId,
        'definition': {
          'surveyName': survey.surveyName,
          'surveyDescription': survey.surveyDescription,
          'deadlineMillis': survey.deadline.toUtc().millisecondsSinceEpoch,
          'timeLimitPerQuestion': survey.timeLimitPerQuestion,
          'surveyType': survey.surveyType.index,
          'questions': [
            for (final source in survey.questions)
              {
                'type': source['type'],
                'question': source['question'],
                if (source['type'] == 'Single' ||
                    source['type'] == 'Multiple')
                  'options': source['options'],
                if (isTest && source['type'] == 'Single')
                  'correctAnswer': source['correctAnswer'],
                if (isTest && source['type'] == 'Multiple')
                  'correctAnswers': source['correctAnswers'],
              },
          ],
        },
      },
    );
    final data = result.data;
    final surveyId = data['surveyId'];
    if (surveyId is! String || surveyId != requestedSurveyId) {
      throw const FormatException(
        'The survey publication response was incomplete.',
      );
    }
    survey.id = surveyId;
    return surveyId;
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

  /// The correct option indexes for each question, for the review screen.
  ///
  /// Only company staff can read this; rules reject everyone else, so a
  /// participant cannot pull the answers before submitting. Returns an empty
  /// list when the read is refused or the survey predates answer keys, which
  /// the caller renders as an unmarked review rather than as a failure.
  Future<List<Set<int>>> fetchAnswerKeyIndexes(String surveyId) async {
    try {
      final snapshot = await _firestore
          .collection('surveyAnswerKeys')
          .doc(surveyId)
          .get();
      return readAnswerKeyIndexes(snapshot.data());
    } on FirebaseException {
      return const [];
    }
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

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUsersByCompanyId(
    String companyId,
  ) {
    return _firestore
        .collection('memberDirectory')
        .where('companyId', isEqualTo: companyId)
        .snapshots();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await MemberDirectory.updateMember(
      firestore: FirebaseFirestore.instance,
      userId: userId,
      fields: {'role': newRole},
    );
  }
}
