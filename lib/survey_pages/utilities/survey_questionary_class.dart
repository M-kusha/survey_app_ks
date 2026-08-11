import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';

enum SurveyType { survey, test }

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
  int responsesRevision;

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
    this.responsesRevision = 0,
  });

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
      'responsesRevision': responsesRevision,
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
          .map(
            (participantData) => Participant.fromFirestore(
              participantData as Map<String, dynamic>,
            ),
          )
          .toList();
    }

    final surveyTypeIndex = data['surveyType'] as int? ?? 0;
    final surveyType =
        surveyTypeIndex >= 0 && surveyTypeIndex < SurveyType.values.length
        ? SurveyType.values[surveyTypeIndex]
        : SurveyType.survey;

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
      responsesRevision:
          data['responsesRevision'] is int && data['responsesRevision'] >= 0
          ? data['responsesRevision'] as int
          : 0,
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
  int profileImageRevision;
  Map<String, bool> textAnswersReviewed;
  int totalCorrectAnswers;
  int? gradedQuestionCount;
  String? gradingStatus;
  List<Map<String, dynamic>> participations;
  String? _directoryName;
  bool _directoryIdentityResolved = false;

  Participant({
    required this.userId,
    required this.name,
    required this.surveyAnswers,
    required this.score,
    this.textAnswer = '',
    this.participantSubmitted = false,
    this.imageProfile = '',
    this.profileImageRevision = 0,
    this.textAnswersReviewed = const {},
    this.totalCorrectAnswers = 0,
    this.gradedQuestionCount,
    this.gradingStatus,
    this.participations = const [],
  });

  /// Applies the current authoritative directory projection. A missing or
  /// malformed projection is a resolved, neutral identity state.
  void resolveDirectoryIdentity(Object? fullName) {
    _directoryIdentityResolved = true;
    _directoryName = fullName is String && fullName.trim().isNotEmpty
        ? fullName
        : null;
  }

  void copyDirectoryIdentityFrom(Participant other) {
    _directoryIdentityResolved = other._directoryIdentityResolved;
    _directoryName = other._directoryName;
  }

  /// Human-readable current-directory rendering. Until the directory has
  /// resolved, or when the UID is absent there, the historical snapshot is
  /// deliberately not exposed.
  String displayName([String unavailableLabel = 'Unknown']) =>
      _directoryIdentityResolved && _directoryName != null
      ? _directoryName!
      : unavailableLabel;

  /// Human-readable attribution for authorized exports. The name is a
  /// rule-verified write-time snapshot; the UID remains the audit identity.
  String auditLabel([String unavailableLabel = 'Unknown']) =>
      '${displayName(unavailableLabel)} · UID $userId';

  Map<String, dynamic> toFirestoreMap() {
    return {
      'userId': userId,
      'name': name,
      'surveyAnswers': surveyAnswers,
      'score': score,
      'textAnswer': textAnswer,
      'participantSubmitted': participantSubmitted,
      'imageProfile': imageProfile,
      'profileImageRevision': profileImageRevision,
      'textAnswersReviewed': textAnswersReviewed,
      "totalCorrectAnswers": totalCorrectAnswers,
      if (gradedQuestionCount != null)
        'gradedQuestionCount': gradedQuestionCount,
      if (gradingStatus != null) 'gradingStatus': gradingStatus,
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
      profileImageRevision: readProfileImageRevision(
        data['profileImageRevision'],
      ),
      textAnswersReviewed: Map<String, bool>.from(
        data['textAnswersReviewed'] ?? {},
      ),
      totalCorrectAnswers: data['totalCorrectAnswers'] ?? 0,
      gradedQuestionCount: data['gradedQuestionCount'] as int?,
      gradingStatus: data['gradingStatus'] as String?,
      participations: List<Map<String, dynamic>>.from(
        data['participations'] ?? [],
      ),
    );
  }
}
