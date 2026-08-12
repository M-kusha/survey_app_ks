import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'package:echomeet/survey_pages/utilities/survey_answer_keys.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';

typedef ContentDeletionCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

class FirebaseSurveyService {
  FirebaseSurveyService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    ContentDeletionCallable? contentDeletionCallable,
  }) : _providedFirestore = firestore,
       _providedFunctions = functions,
       _deleteContent =
           contentDeletionCallable ??
           ((payload) => _firebaseContentDeletion(functions, payload));

  final FirebaseFirestore? _providedFirestore;
  final FirebaseFunctions? _providedFunctions;
  final ContentDeletionCallable _deleteContent;
  FirebaseFirestore get _firestore =>
      _providedFirestore ?? FirebaseFirestore.instance;
  FirebaseFunctions get _functions =>
      _providedFunctions ??
      FirebaseFunctions.instanceFor(region: 'europe-west4');

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
    final result = await callable.call<Map<String, dynamic>>({
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
              if (source['type'] == 'Single' || source['type'] == 'Multiple')
                'options': source['options'],
              if (isTest && source['type'] == 'Single')
                'correctAnswer': source['correctAnswer'],
              if (isTest && source['type'] == 'Multiple')
                'correctAnswers': source['correctAnswers'],
            },
        ],
      },
    });
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
    final result = await _deleteContent({
      'entityType': 'survey',
      'entityId': surveyId,
    });
    if (result['deleted'] != true ||
        result['entityType'] != 'survey' ||
        result['entityId'] != surveyId) {
      throw const FormatException(
        'The content deletion response was incomplete.',
      );
    }
  }

  static Future<Map<String, dynamic>> _firebaseContentDeletion(
    FirebaseFunctions? functions,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await (functions ??
                FirebaseFunctions.instanceFor(region: 'europe-west4'))
            .httpsCallable(
              'deleteContent',
              options: HttpsCallableOptions(
                timeout: const Duration(minutes: 2),
              ),
            )
            .call<Map<String, dynamic>>(payload);
    return result.data;
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
}
