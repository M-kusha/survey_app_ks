import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'survey_questionary_class.dart';

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
  Completer<void>? _firstSurveys;
  Completer<void>? _firstParticipants;
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _participationSubscriptions = {};

  String? _authUserId;
  String? _companyId;
  String? _participationUserId;
  String? _participantsSurveyId;
  Set<String> _pendingParticipationSurveyIds = {};
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
    final previousParticipationSubscriptions =
        _takeParticipationSubscriptions();
    _surveysSubscription = null;
    _participantsSubscription = null;
    _completeFirstSurveys();
    _completeFirstParticipants();
    _companyId = companyId;
    _participationUserId = null;
    _participantsSurveyId = null;
    _participants = null;
    _surveys = [];
    userParticipationStatus = {};
    _pendingParticipationSurveyIds = {};
    _isLoading = true;
    _error = null;
    _notify();

    await Future.wait([
      if (previousSubscription != null) previousSubscription.cancel(),
      if (previousParticipantsSubscription != null)
        previousParticipantsSubscription.cancel(),
      ...previousParticipationSubscriptions.map(
        (subscription) => subscription.cancel(),
      ),
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

            _surveys = snapshot.docs
                .map((doc) => Survey.fromFirestore(doc.data()))
                .toList();
            _isLoading = false;
            _error = null;
            unawaited(
              _synchronizeParticipationSubscriptions(_participationGeneration),
            );
            _notify();

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
        _participantsSubscription != null) {
      await _firstParticipants?.future;
      return;
    }

    final generation = ++_participantsGeneration;
    final previousSubscription = _participantsSubscription;
    final previousFirst = _firstParticipants;
    _participantsSubscription = null;
    _firstParticipants = null;
    _participantsSurveyId = surveyId;
    _participants = null;
    if (previousFirst != null && !previousFirst.isCompleted) {
      previousFirst.complete();
    }
    await previousSubscription?.cancel();
    if (_disposed || generation != _participantsGeneration) return;

    final firstSnapshot = Completer<void>();
    _firstParticipants = firstSnapshot;
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
            _error = null;
            _notify();
            if (!firstSnapshot.isCompleted) firstSnapshot.complete();
            if (identical(_firstParticipants, firstSnapshot)) {
              _firstParticipants = null;
            }
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

    await firstSnapshot.future;
  }

  Future<void> checkParticipationForCurrentUser(String userId) async {
    if (_participationUserId == userId &&
        _participationSubscriptions.length == _surveys.length &&
        _error == null) {
      return;
    }

    final generation = ++_participationGeneration;
    final previousSubscriptions = _takeParticipationSubscriptions();
    _participationUserId = userId;
    userParticipationStatus = {};
    _pendingParticipationSurveyIds = {for (final survey in _surveys) survey.id};
    _isLoading = true;
    _error = null;
    _notify();

    await Future.wait([
      for (final subscription in previousSubscriptions) subscription.cancel(),
    ]);
    if (_disposed || generation != _participationGeneration) return;

    if (userId.isEmpty) {
      _pendingParticipationSurveyIds = {};
      _isLoading = false;
      _notify();
      return;
    }
    await _synchronizeParticipationSubscriptions(generation);
    if (_disposed || generation != _participationGeneration) return;

    if (_pendingParticipationSurveyIds.isEmpty) _isLoading = false;
    _notify();
  }

  Future<void> _synchronizeParticipationSubscriptions(int generation) async {
    if (_disposed || generation != _participationGeneration) return;
    final userId = _participationUserId;
    if (userId == null || userId.isEmpty) return;

    final surveyIds = _surveys.map((survey) => survey.id).toSet();
    final removed = _participationSubscriptions.keys
        .where((surveyId) => !surveyIds.contains(surveyId))
        .toList();
    final removedSubscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];
    for (final surveyId in removed) {
      final subscription = _participationSubscriptions.remove(surveyId);
      if (subscription != null) removedSubscriptions.add(subscription);
      userParticipationStatus.remove(surveyId);
      _pendingParticipationSurveyIds.remove(surveyId);
    }
    await Future.wait([
      for (final subscription in removedSubscriptions) subscription.cancel(),
    ]);
    if (_disposed || generation != _participationGeneration) return;
    if (_pendingParticipationSurveyIds.isEmpty) _isLoading = false;

    for (final surveyId in surveyIds) {
      if (_disposed || generation != _participationGeneration) return;
      if (_participationSubscriptions.containsKey(surveyId)) continue;

      final subscription = _firestore
          .collection('surveys')
          .doc(surveyId)
          .collection('participants')
          .doc(userId)
          .snapshots()
          .listen(
            (document) {
              if (_disposed ||
                  generation != _participationGeneration ||
                  _participationUserId != userId ||
                  !_surveys.any((survey) => survey.id == surveyId)) {
                return;
              }

              userParticipationStatus[surveyId] =
                  document.exists &&
                  document.data()?['participantSubmitted'] == true;
              _pendingParticipationSurveyIds.remove(surveyId);
              if (_pendingParticipationSurveyIds.isEmpty) _isLoading = false;
              _error = null;
              _notify();
            },
            onError: (Object error) {
              if (_disposed ||
                  generation != _participationGeneration ||
                  _participationUserId != userId) {
                return;
              }
              _pendingParticipationSurveyIds.remove(surveyId);
              if (_pendingParticipationSurveyIds.isEmpty) _isLoading = false;
              _error = error;
              _notify();
            },
          );
      _participationSubscriptions[surveyId] = subscription;
    }
  }

  List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
  _takeParticipationSubscriptions() {
    final subscriptions = _participationSubscriptions.values.toList();
    _participationSubscriptions.clear();
    return subscriptions;
  }

  Future<void> clear() async {
    ++_surveyLoadGeneration;
    ++_participationGeneration;
    ++_participantsGeneration;
    final surveysSubscription = _surveysSubscription;
    final participantsSubscription = _participantsSubscription;
    final participationSubscriptions = _takeParticipationSubscriptions();
    _surveysSubscription = null;
    _participantsSubscription = null;
    _completeFirstSurveys();
    _completeFirstParticipants();
    _companyId = null;
    _participationUserId = null;
    _participantsSurveyId = null;
    _pendingParticipationSurveyIds = {};
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
      ...participationSubscriptions.map(
        (subscription) => subscription.cancel(),
      ),
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
    for (final subscription in _takeParticipationSubscriptions()) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
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
