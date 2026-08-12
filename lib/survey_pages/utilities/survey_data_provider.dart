import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'survey_questionary_class.dart';

void applyParticipantDirectorySnapshot(
  Iterable<Participant> participants,
  Map<String, String> memberNames,
) {
  for (final participant in participants) {
    participant.resolveDirectoryIdentity(memberNames[participant.userId]);
  }
}

void applyParticipantDirectoryError(Iterable<Participant> participants) {
  for (final participant in participants) {
    participant.resolveDirectoryIdentity(null);
  }
}

class SurveyDataProvider extends ChangeNotifier {
  SurveyDataProvider({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _authUserId = _auth.currentUser?.uid;
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (_disposed) return;
      if (user?.uid != _authUserId) {
        _authUserId = user?.uid;
        unawaited(clear());
      }
    });
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _surveysSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _participantsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _participantMembersSubscription;
  Completer<void>? _firstSurveys;
  Completer<void>? _firstParticipants;

  String? _authUserId;
  String? _companyId;
  String? _participationUserId;
  String? _participantsSurveyId;
  Set<String> _pendingParticipationSurveyIds = {};
  final Set<String> _locallySubmittedSurveyIds = {};
  Map<String, int> _responsesRevisions = {};
  int _surveyLoadGeneration = 0;
  int _participationGeneration = 0;
  int _participantsGeneration = 0;
  bool _disposed = false;

  Survey? _currentSurvey;
  List<Participant>? _participants;
  List<Survey> _surveys = [];
  Survey? get currentSurvey => _currentSurvey;
  List<Participant>? get participants => _participants;
  List<Survey> get surveys => _surveys;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  Object? _error;
  Object? get error => _error;
  Map<String, bool> userParticipationStatus = {};

  Future<void> loadSurveys(String companyId) async {
    _authUserId = _auth.currentUser?.uid;
    if (_companyId == companyId &&
        _surveysSubscription != null &&
        _error == null) {
      return;
    }

    final generation = ++_surveyLoadGeneration;
    ++_participationGeneration;
    ++_participantsGeneration;
    final previousSubscription = _surveysSubscription;
    final previousParticipantsSubscription = _participantsSubscription;
    final previousParticipantMembersSubscription =
        _participantMembersSubscription;
    _surveysSubscription = null;
    _participantsSubscription = null;
    _participantMembersSubscription = null;
    _completeFirstSurveys();
    _completeFirstParticipants();
    _companyId = companyId;
    _participationUserId = null;
    _participantsSurveyId = null;
    _participants = null;
    _surveys = [];
    userParticipationStatus = {};
    _pendingParticipationSurveyIds = {};
    _locallySubmittedSurveyIds.clear();
    _responsesRevisions = {};
    _isLoading = true;
    _error = null;
    _notify();

    await Future.wait([
      if (previousSubscription != null) previousSubscription.cancel(),
      if (previousParticipantsSubscription != null)
        previousParticipantsSubscription.cancel(),
      if (previousParticipantMembersSubscription != null)
        previousParticipantMembersSubscription.cancel(),
    ]);
    if (_disposed || generation != _surveyLoadGeneration) return;

    final firstSnapshot = Completer<void>();
    _firstSurveys = firstSnapshot;
    _surveysSubscription = _firestore
        .collection('surveys')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .listen(
          (snapshot) {
            if (_disposed ||
                generation != _surveyLoadGeneration ||
                _companyId != companyId) {
              return;
            }

            final nextSurveys = readSurveySnapshot(
              snapshot.docs.map((doc) => doc.data()),
            );
            final nextRevisions = {
              for (final survey in nextSurveys)
                survey.id: survey.responsesRevision,
            };
            final changedSurveyIds = nextRevisions.keys
                .where(
                  (surveyId) =>
                      _responsesRevisions.containsKey(surveyId) &&
                      _responsesRevisions[surveyId] != nextRevisions[surveyId],
                )
                .toSet();
            _surveys = nextSurveys;
            _responsesRevisions = nextRevisions;

            if (changedSurveyIds.isNotEmpty &&
                _participationUserId?.isNotEmpty == true) {
              // Invalidate all in-flight reads. A response revision can arrive
              // after a local submit, so an older pre-submit get must never
              // overwrite the successful local state.
              ++_participationGeneration;
              _pendingParticipationSurveyIds.clear();
              for (final surveyId in changedSurveyIds) {
                userParticipationStatus.remove(surveyId);
                _locallySubmittedSurveyIds.remove(surveyId);
              }
            }
            _isLoading = _pendingParticipationSurveyIds.isNotEmpty;
            _error = null;
            final participationHydration = _synchronizeParticipationStatus(
              _participationGeneration,
            );
            _notify();
            unawaited(participationHydration);

            if (!firstSnapshot.isCompleted) firstSnapshot.complete();
            if (identical(_firstSurveys, firstSnapshot)) {
              _firstSurveys = null;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed ||
                generation != _surveyLoadGeneration ||
                _companyId != companyId) {
              return;
            }
            _isLoading = false;
            _error = error;
            _notify();

            if (!firstSnapshot.isCompleted) {
              firstSnapshot.completeError(error, stackTrace);
            }
            if (identical(_firstSurveys, firstSnapshot)) {
              _firstSurveys = null;
            }
          },
        );

    await firstSnapshot.future;
  }

  Future<void> loadParticipants(String surveyId) async {
    if (_participantsSurveyId == surveyId &&
        _participantsSubscription != null &&
        _participantMembersSubscription != null) {
      await _firstParticipants?.future;
      return;
    }

    final generation = ++_participantsGeneration;
    final previousSubscription = _participantsSubscription;
    final previousMembersSubscription = _participantMembersSubscription;
    final previousFirst = _firstParticipants;
    _participantsSubscription = null;
    _participantMembersSubscription = null;
    _firstParticipants = null;
    _participantsSurveyId = surveyId;
    _participants = null;
    if (previousFirst != null && !previousFirst.isCompleted) {
      previousFirst.complete();
    }
    await Future.wait([
      if (previousSubscription != null) previousSubscription.cancel(),
      if (previousMembersSubscription != null)
        previousMembersSubscription.cancel(),
    ]);
    if (_disposed || generation != _participantsGeneration) return;

    final firstSnapshot = Completer<void>();
    _firstParticipants = firstSnapshot;
    var participantsSeen = false;
    var membersSeen = false;
    var memberNames = const <String, String>{};

    void applyDirectoryIdentity() {
      final participants = _participants;
      if (!membersSeen || participants == null) return;
      applyParticipantDirectorySnapshot(participants, memberNames);
    }

    void completeFirstSnapshot() {
      if (!participantsSeen || !membersSeen || firstSnapshot.isCompleted) {
        return;
      }
      firstSnapshot.complete();
      if (identical(_firstParticipants, firstSnapshot)) {
        _firstParticipants = null;
      }
    }

    _participantsSubscription = _firestore
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .snapshots()
        .listen(
          (snapshot) {
            if (_disposed ||
                generation != _participantsGeneration ||
                _participantsSurveyId != surveyId) {
              return;
            }
            _participants = snapshot.docs
                .map((doc) => Participant.fromFirestore(doc.data()))
                .toList();
            participantsSeen = true;
            applyDirectoryIdentity();
            _error = null;
            _notify();
            completeFirstSnapshot();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed ||
                generation != _participantsGeneration ||
                _participantsSurveyId != surveyId) {
              return;
            }
            _error = error;
            _notify();
            if (!firstSnapshot.isCompleted) {
              firstSnapshot.completeError(error, stackTrace);
            }
            if (identical(_firstParticipants, firstSnapshot)) {
              _firstParticipants = null;
            }
          },
        );

    final companyId = _companyId?.trim() ?? '';
    if (companyId.isEmpty) {
      membersSeen = true;
      applyDirectoryIdentity();
      completeFirstSnapshot();
    } else {
      _participantMembersSubscription = _firestore
          .collection('memberDirectory')
          .where('companyId', isEqualTo: companyId)
          .snapshots()
          .listen(
            (snapshot) {
              if (_disposed ||
                  generation != _participantsGeneration ||
                  _participantsSurveyId != surveyId) {
                return;
              }
              memberNames = {
                for (final document in snapshot.docs)
                  if (document.data()['fullName'] case final String name
                      when name.trim().isNotEmpty)
                    document.id: name,
              };
              membersSeen = true;
              applyDirectoryIdentity();
              _notify();
              completeFirstSnapshot();
            },
            onError: (Object _) {
              if (_disposed ||
                  generation != _participantsGeneration ||
                  _participantsSurveyId != surveyId) {
                return;
              }
              // Fail closed: results remain available, but names do not fall
              // back to participant-authored or stale snapshot data.
              memberNames = const {};
              membersSeen = true;
              final participants = _participants;
              if (participants != null) {
                applyParticipantDirectoryError(participants);
              }
              _notify();
              completeFirstSnapshot();
            },
          );
    }

    await firstSnapshot.future;
  }

  Future<void> checkParticipationForCurrentUser(String userId) async {
    final generation = ++_participationGeneration;
    if (_participationUserId != userId) {
      _locallySubmittedSurveyIds.clear();
    }
    _participationUserId = userId;
    userParticipationStatus = {};
    _pendingParticipationSurveyIds = {};
    _isLoading = true;
    _error = null;
    _notify();

    if (userId.isEmpty) {
      _isLoading = false;
      _notify();
      return;
    }
    await _synchronizeParticipationStatus(generation);
  }

  void markParticipationSubmitted({
    required String surveyId,
    required String userId,
  }) {
    if (_disposed ||
        userId.isEmpty ||
        _auth.currentUser?.uid != userId ||
        _participationUserId != userId) {
      return;
    }

    final changed = userParticipationStatus[surveyId] != true;
    _locallySubmittedSurveyIds.add(surveyId);
    userParticipationStatus[surveyId] = true;
    final wasPending = _pendingParticipationSurveyIds.remove(surveyId);
    if (_pendingParticipationSurveyIds.isEmpty) _isLoading = false;
    if (changed || wasPending) _notify();
  }

  Future<void> _synchronizeParticipationStatus(int generation) {
    if (_disposed || generation != _participationGeneration) {
      return Future.value();
    }
    final userId = _participationUserId;
    if (userId == null || userId.isEmpty) return Future.value();

    final surveyIds = _surveys.map((survey) => survey.id).toSet();
    userParticipationStatus.removeWhere(
      (surveyId, _) => !surveyIds.contains(surveyId),
    );
    _pendingParticipationSurveyIds.removeWhere(
      (surveyId) => !surveyIds.contains(surveyId),
    );
    _locallySubmittedSurveyIds.removeWhere(
      (surveyId) => !surveyIds.contains(surveyId),
    );

    final missingSurveyIds = surveyIds
        .where(
          (surveyId) =>
              !userParticipationStatus.containsKey(surveyId) &&
              !_pendingParticipationSurveyIds.contains(surveyId),
        )
        .toList();
    if (missingSurveyIds.isEmpty) {
      final wasLoading = _isLoading;
      _isLoading = _pendingParticipationSurveyIds.isNotEmpty;
      if (wasLoading != _isLoading) _notify();
      return Future.value();
    }

    _pendingParticipationSurveyIds.addAll(missingSurveyIds);
    _isLoading = true;
    return _hydrateParticipationStatus(
      generation: generation,
      userId: userId,
      surveyIds: missingSurveyIds,
    );
  }

  Future<void> _hydrateParticipationStatus({
    required int generation,
    required String userId,
    required List<String> surveyIds,
  }) async {
    Object? firstError;

    const batchSize = 8;
    for (var offset = 0; offset < surveyIds.length; offset += batchSize) {
      final end = offset + batchSize < surveyIds.length
          ? offset + batchSize
          : surveyIds.length;
      final batch = surveyIds.sublist(offset, end);
      final results = await Future.wait([
        for (final surveyId in batch)
          _readParticipationStatus(surveyId: surveyId, userId: userId),
      ]);
      if (_disposed ||
          generation != _participationGeneration ||
          _participationUserId != userId) {
        return;
      }

      final currentSurveyIds = _surveys.map((survey) => survey.id).toSet();
      for (final result in results) {
        _pendingParticipationSurveyIds.remove(result.surveyId);
        if (!currentSurveyIds.contains(result.surveyId)) continue;
        if (result.error case final error?) {
          firstError ??= error;
        } else {
          userParticipationStatus[result.surveyId] =
              _locallySubmittedSurveyIds.contains(result.surveyId) ||
              result.participated!;
        }
      }
    }

    _isLoading = _pendingParticipationSurveyIds.isNotEmpty;
    if (firstError != null) _error = firstError;
    _notify();
  }

  Future<({String surveyId, bool? participated, Object? error})>
  _readParticipationStatus({
    required String surveyId,
    required String userId,
  }) async {
    try {
      final document = await _firestore
          .collection('surveys')
          .doc(surveyId)
          .collection('participants')
          .doc(userId)
          .get();
      return (
        surveyId: surveyId,
        participated:
            document.exists && document.data()?['participantSubmitted'] == true,
        error: null,
      );
    } catch (error) {
      return (surveyId: surveyId, participated: null, error: error);
    }
  }

  Future<void> clear() async {
    ++_surveyLoadGeneration;
    ++_participationGeneration;
    ++_participantsGeneration;
    final surveysSubscription = _surveysSubscription;
    final participantsSubscription = _participantsSubscription;
    final participantMembersSubscription = _participantMembersSubscription;
    _surveysSubscription = null;
    _participantsSubscription = null;
    _participantMembersSubscription = null;
    _completeFirstSurveys();
    _completeFirstParticipants();
    _companyId = null;
    _participationUserId = null;
    _participantsSurveyId = null;
    _pendingParticipationSurveyIds = {};
    _locallySubmittedSurveyIds.clear();
    _responsesRevisions = {};
    _currentSurvey = null;
    _participants = null;
    _surveys = [];
    userParticipationStatus = {};
    _isLoading = false;
    _error = null;
    _notify();
    await Future.wait([
      if (surveysSubscription != null) surveysSubscription.cancel(),
      if (participantsSubscription != null) participantsSubscription.cancel(),
      if (participantMembersSubscription != null)
        participantMembersSubscription.cancel(),
    ]);
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _completeFirstSurveys() {
    final firstSurveys = _firstSurveys;
    _firstSurveys = null;
    if (firstSurveys != null && !firstSurveys.isCompleted) {
      firstSurveys.complete();
    }
  }

  void _completeFirstParticipants() {
    final firstParticipants = _firstParticipants;
    _firstParticipants = null;
    if (firstParticipants != null && !firstParticipants.isCompleted) {
      firstParticipants.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_surveyLoadGeneration;
    ++_participationGeneration;
    ++_participantsGeneration;
    _completeFirstSurveys();
    _completeFirstParticipants();
    unawaited(_authSubscription?.cancel());
    unawaited(_surveysSubscription?.cancel());
    unawaited(_participantsSubscription?.cancel());
    unawaited(_participantMembersSubscription?.cancel());
    super.dispose();
  }
}

/// Reads the independently useful rows in a survey-list snapshot.
///
/// A trusted deletion first stamps the parent with [deletionStartedAt], then
/// clears its descendants and removes it. The stamped survey must leave the
/// list immediately. Any other unreadable document is isolated to that row so
/// it cannot keep the previous complete list on screen by throwing out of the
/// stream callback before assignment and notification.
List<Survey> readSurveySnapshot(
  Iterable<Map<String, dynamic>> documents, {
  void Function(Object error)? onUnreadable,
}) {
  final surveys = <Survey>[];
  for (final document in documents) {
    try {
      if (document.containsKey('deletionStartedAt')) {
        if (document['deletionStartedAt'] is! Timestamp) {
          throw const FormatException('Survey deletion state is invalid.');
        }
        continue;
      }
      surveys.add(Survey.fromFirestore(document));
    } on Object catch (error) {
      // The try/catch is deliberately limited to decoding this one Firestore
      // row. In particular, TypeError from a malformed Timestamp or collection
      // cast is data-local and must not terminate the list listener.
      (onUnreadable ?? _reportUnreadableSurvey)(error);
    }
  }
  return surveys;
}

void _reportUnreadableSurvey(Object error) {
  assert(() {
    debugPrint('Skipped an unreadable survey: $error');
    return true;
  }());
}

enum UserRole { admin, moderator, user }

extension UserRoleExtension on UserRole {
  String toShortString() {
    return toString().split('.').last;
  }
}

class UserModel {
  final String id;
  final String name;
  final String profileImage;
  final int profileImageRevision;
  final String companyId;
  String role;

  String membership;

  bool banned;

  UserModel({
    required this.id,
    required this.name,
    required this.profileImage,
    this.profileImageRevision = 0,
    required this.companyId,
    required this.role,
    this.membership = 'active',
    this.banned = false,
  });

  bool get isPending => membership == 'pending';

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      name: data['fullName'] ?? '',
      profileImage: data['profileImage'] ?? '',
      profileImageRevision: readProfileImageRevision(
        data['profileImageRevision'],
      ),
      companyId: data['companyId'] ?? '',
      role: data['role'] ?? 'user',
      membership: data['membership'] ?? 'active',
    );
  }
}

class UserDataProvider extends ChangeNotifier {
  UserDataProvider({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _authSubscription = _auth.authStateChanges().listen(
      (user) => _watchUser(user?.uid),
    );
  }

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _profileSubscription;
  String? _watchedUserId;
  Completer<void>? _firstProfile;
  int _watchGeneration = 0;

  UserModel? _currentUser;
  Object? _error;
  bool _disposed = false;

  UserModel? get currentUser => _currentUser;
  Object? get error => _error;

  Future<void> loadCurrentUser() async {
    final userId = _auth.currentUser?.uid;
    _watchUser(userId);
    if (userId != null && _currentUser?.id != userId) {
      await _firstProfile?.future;
    }
  }

  void _watchUser(String? userId) {
    if (_disposed) return;
    if (_watchedUserId == userId && _profileSubscription != null) return;

    final generation = ++_watchGeneration;
    final previousProfileSubscription = _profileSubscription;
    final previousFirstProfile = _firstProfile;
    _profileSubscription = null;
    _firstProfile = null;
    unawaited(previousProfileSubscription?.cancel());
    if (previousFirstProfile != null && !previousFirstProfile.isCompleted) {
      previousFirstProfile.complete();
    }
    _watchedUserId = userId;
    _currentUser = null;
    _error = null;

    if (userId == null || userId.isEmpty) {
      _notify();
      return;
    }

    final firstProfile = Completer<void>();
    _firstProfile = firstProfile;
    _profileSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (document) {
            if (_disposed ||
                generation != _watchGeneration ||
                _watchedUserId != userId) {
              return;
            }
            _currentUser = document.exists
                ? UserModel.fromFirestore(document)
                : null;
            _error = null;
            _notify();
            if (!firstProfile.isCompleted) firstProfile.complete();
          },
          onError: (Object error) {
            if (_disposed ||
                generation != _watchGeneration ||
                _watchedUserId != userId) {
              return;
            }
            _profileSubscription = null;
            _currentUser = null;
            _error = error;
            _notify();
            if (!firstProfile.isCompleted) firstProfile.complete();
          },
        );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_watchGeneration;
    final firstProfile = _firstProfile;
    _firstProfile = null;
    if (firstProfile != null && !firstProfile.isCompleted) {
      firstProfile.complete();
    }
    unawaited(_authSubscription?.cancel());
    unawaited(_profileSubscription?.cancel());
    super.dispose();
  }
}
