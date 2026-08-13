import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/profile/authenticated_profile_image.dart';
import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'package:echomeet/core/profile/profile_image_upload_error.dart';
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
  int? _pendingProfileImageExpectedRevision;
  Future<ProfileImageUploadResult>? _profileImageUpload;

  Uint8List? get pendingProfileImage => _pendingProfileImage;
  bool get hasPendingProfileImage => _pendingProfileImage != null;

  void setProfileImage(Uint8List image) {
    _pendingProfileImage = image;
    _pendingProfileImageExpectedRevision = null;
  }

  void resetForRegistration() {
    emailController.clear();
    passwordController.clear();
    fullnameController.clear();
    birthdateController.clear();
    companyNameController.clear();
    selectedCompanyName = null;
    _pendingProfileImage = null;
    _pendingProfileImageExpectedRevision = null;
  }

  Future<ProfileImageUploadResult> uploadPendingProfileImage() {
    if (_pendingProfileImage == null) {
      return Future.value(const ProfileImageUploadResult.success());
    }
    return _profileImageUpload ??= _uploadPendingProfileImage().whenComplete(
      () => _profileImageUpload = null,
    );
  }

  Future<ProfileImageUploadResult> _uploadPendingProfileImage() async {
    final user = _auth.currentUser;
    final image = _pendingProfileImage;
    if (user == null) {
      return const ProfileImageUploadResult.failed(
        'profile_image_sign_in_again',
      );
    }
    if (user.emailVerified != true) {
      return const ProfileImageUploadResult.failed(
        'profile_image_verify_email',
      );
    }
    if (image == null) {
      return const ProfileImageUploadResult.success();
    }
    try {
      var expectedRevision = _pendingProfileImageExpectedRevision;
      if (expectedRevision == null) {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.server));
        if (!profile.exists) {
          return const ProfileImageUploadResult.failed(
            'profile_image_account_unavailable',
          );
        }
        expectedRevision = validatedProfileImageRevision(
          profile.data()?['profileImageRevision'],
        );
        if (expectedRevision == null) {
          return const ProfileImageUploadResult.failed(
            'profile_image_account_unavailable',
          );
        }
        _pendingProfileImageExpectedRevision = expectedRevision;
      }
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west4')
          .httpsCallable('uploadProfileImage')
          .call<Map<String, dynamic>>({
            'jpegBase64': base64Encode(image),
            'expectedRevision': expectedRevision,
          });
      if (result.data['path'] != profileImagePathFor(user.uid)) {
        return const ProfileImageUploadResult.failed(
          'error_updating_profile_image',
        );
      }
      final revision = result.data['revision'];
      if (revision is! int || revision != expectedRevision + 1) {
        return const ProfileImageUploadResult.failed(
          'error_updating_profile_image',
        );
      }
      _pendingProfileImage = null;
      _pendingProfileImageExpectedRevision = null;
      return const ProfileImageUploadResult.success();
    } catch (error) {
      return ProfileImageUploadResult.failed(profileImageUploadErrorKey(error));
    }
  }

  Future<void> registerUser({
    required ProfileType profileType,
    String? existingCompanyId,
  }) async {
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
        if (companyId.isNotEmpty) {
          profile.addAll({
            'pendingOnboardingType': 'joinCompany',
            'pendingCompanyId': companyId,
          });
        }
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(profile);
      profilePersisted = true;
    } catch (_) {
      if (!profilePersisted) await user.delete().catchError((_) {});
      rethrow;
    }

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
