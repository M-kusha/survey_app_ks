import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/login/login_logics.dart';
import 'package:flutter/material.dart';

enum ProfileType { user, company }

class CompanyNameTakenException implements Exception {
  const CompanyNameTakenException();
}

class CompanyNameInvalidException implements Exception {
  const CompanyNameInvalidException();
}

class EmailAlreadyRegisteredException implements Exception {
  const EmailAlreadyRegisteredException();
}

class WeakPasswordException implements Exception {
  const WeakPasswordException();
}

String registrationErrorKey(Object error) => switch (error) {
  EmailAlreadyRegisteredException() => 'email_already_exists',
  CompanyNameTakenException() => 'company_name_taken',
  CompanyNameInvalidException() => 'company_name_invalid',
  WeakPasswordException() => 'validate_password_strong',
  _ => 'error_occurred',
};

class RegisterLogic {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController fullnameController = TextEditingController();
  final TextEditingController birthdateController = TextEditingController();
  final TextEditingController companyNameController = TextEditingController();

  String? selectedCompanyName;
  Uint8List? _pendingProfileImage;
  Future<bool>? _profileImageUpload;

  Uint8List? get pendingProfileImage => _pendingProfileImage;
  bool get hasPendingProfileImage => _pendingProfileImage != null;

  void setProfileImage(Uint8List image) {
    _pendingProfileImage = image;
  }

  void resetForRegistration() {
    emailController.clear();
    passwordController.clear();
    fullnameController.clear();
    birthdateController.clear();
    companyNameController.clear();
    selectedCompanyName = null;
    _pendingProfileImage = null;
  }

  Future<bool> uploadPendingProfileImage() {
    if (_pendingProfileImage == null) return Future.value(true);
    return _profileImageUpload ??= _uploadPendingProfileImage().whenComplete(
      () => _profileImageUpload = null,
    );
  }

  Future<bool> _uploadPendingProfileImage() async {
    final user = _auth.currentUser;
    final image = _pendingProfileImage;
    if (user == null || user.emailVerified != true || image == null) {
      return false;
    }

    try {
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('uploadProfileImage')
          .call<Map<String, dynamic>>({'jpegBase64': base64Encode(image)});
      if (result.data['path'] != profileImagePathFor(user.uid)) return false;
      final revision = result.data['revision'];
      if (revision is! int || revision < 1) return false;
      _pendingProfileImage = null;
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> registerUser({
    required ProfileType profileType,
    String? existingCompanyId,
  }) async {
    // createUserWithEmailAndPassword replaces Firebase's current account.
    // Cleanup and sign out first so a push token cannot remain on that profile.
    if (_auth.currentUser != null && !await AuthManager().signOut()) {
      throw StateError('The existing session could not be closed safely.');
    }
    final UserCredential userCredential;
    try {
      userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
    } on FirebaseAuthException catch (e) {
      throw switch (e.code) {
        'email-already-in-use' => const EmailAlreadyRegisteredException(),
        'weak-password' => const WeakPasswordException(),
        _ => e,
      };
    }

    final user = userCredential.user!;
    var profilePersisted = false;
    try {
      await user.sendEmailVerification();

      final languageCode =
          WidgetsBinding.instance.platformDispatcher.locale.languageCode;
      final notificationLocale = const {'en', 'de', 'sq'}.contains(languageCode)
          ? languageCode
          : 'en';
      final profile = <String, dynamic>{
        'fullName': fullnameController.text.trim(),
        'birthdate': birthdateController.text.trim(),
        'email': user.email ?? emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'companyId': '',
        'role': 'user',
        'membership': 'active',
        'notificationLocale': notificationLocale,
      };

      if (profileType == ProfileType.company) {
        profile.addAll({
          'pendingOnboardingType': 'createCompany',
          'pendingCompanyName': companyNameController.text.trim(),
        });
      } else {
        final companyId = (existingCompanyId ?? '').trim();
        if (companyId.isEmpty) {
          throw StateError('A company must be selected.');
        }
        profile.addAll({
          'pendingOnboardingType': 'joinCompany',
          'pendingCompanyId': companyId,
        });
      }

      // This is the only Firestore state an unverified registration creates.
      // Tenant documents, name locks and memberDirectory projections are
      // deferred to the verified callable and committed there atomically.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profile);
      profilePersisted = true;
    } catch (_) {
      if (!profilePersisted) await user.delete().catchError((_) {});
      rethrow;
    }

    // Force the next sign-in to mint a fresh token containing the verified
    // email claim. The profile screen offers avatar upload after verification;
    // registration itself creates no Storage or public directory state.
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> searchCompanies(String query) async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('companyDirectory')
        .get();
    return querySnapshot.docs
        .map((doc) => {'id': doc.id, 'name': doc.data()['name'] as String})
        .where(
          (company) => company['name'].toString().toLowerCase().contains(
            query.toLowerCase(),
          ),
        )
        .toList();
  }

  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullnameController.dispose();
    birthdateController.dispose();
    companyNameController.dispose();
  }
}
