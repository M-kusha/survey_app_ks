import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'survey_questionary_class.dart';

class SurveyDataProvider extends ChangeNotifier {
  Survey? _currentSurvey;
  List<Participant>? _participants;
  List<Survey> _surveys = [];
  Survey? get currentSurvey => _currentSurvey;
  List<Participant>? get participants => _participants;
  List<Survey> get surveys => _surveys;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  Map<String, bool> userParticipationStatus = {};

  Future<void> loadSurveys(String companyId) async {
    _isLoading = true;
    notifyListeners();

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('surveys')
        .where('companyId', isEqualTo: companyId)
        .get();

    _surveys = snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Survey.fromFirestore(data);
    }).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadParticipants(String surveyId) async {
    final participantsSnapshot = await FirebaseFirestore.instance
        .collection('surveys')
        .doc(surveyId)
        .collection('participants')
        .get();

    _participants = participantsSnapshot.docs
        .map((doc) => Participant.fromFirestore(doc.data()))
        .toList();

    notifyListeners();
  }

  Future<void> checkParticipationForCurrentUser(String userId) async {
    _isLoading = true;
    notifyListeners();

    List<Future> checks = [];
    for (var survey in _surveys) {
      checks.add(FirebaseFirestore.instance
          .collection('surveys')
          .doc(survey.id)
          .collection('participants')
          .doc(userId)
          .get()
          .then((doc) => userParticipationStatus[survey.id] = doc.exists &&
              (doc.data() as Map<String, dynamic>)['participantSubmitted'] ==
                  true));
    }

    await Future.wait(checks);

    _isLoading = false;
    notifyListeners();
  }
}

// Assuming UserRole is defined like this
enum UserRole { admin, moderator, user }

extension UserRoleExtension on UserRole {
  String toShortString() {
    return toString().split('.').last;
  }
}

// Your UserModel needs to properly handle the role
class UserModel {
  final String id;
  final String name;
  final String profileImage;
  final String companyId;
  String role; // Role is now a String

  UserModel({
    required this.id,
    required this.name,
    required this.profileImage,
    required this.companyId,
    required this.role,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>? ?? {};
    return UserModel(
      id: doc.id,
      name: data['fullName'] ?? '',
      profileImage: data['profileImage'] ?? '',
      companyId: data['companyId'] ?? '',
      role: data['role'] ?? 'user',
    );
  }
}

class UserDataProvider extends ChangeNotifier {
  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Future<void> loadCurrentUser() async {
    String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      _currentUser = UserModel.fromFirestore(userDoc);
      notifyListeners();
    }
  }
}
