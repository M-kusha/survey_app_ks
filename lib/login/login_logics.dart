import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/profile/profile_image_cache.dart';
import 'package:echomeet/core/notifications/push_service.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum SignInFailure {
  invalidCredentials,
  emailNotVerified,
  sessionCleanupFailed,
}

class AuthManager {
  AuthManager({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    PushService? pushService,
  }) : _authOverride = auth,
       _firestoreOverride = firestore,
       _pushOverride = pushService;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final PushService? _pushOverride;

  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;
  late final FirebaseFirestore _firestore =
      _firestoreOverride ?? FirebaseFirestore.instance;
  late final PushService _push = _pushOverride ?? PushService();

  SignInFailure? lastFailure;

  Future<bool> signInWithEmailAndPassword(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    lastFailure = null;
    try {
      if (_auth.currentUser != null && !await signOut()) {
        lastFailure = SignInFailure.sessionCleanupFailed;
        return false;
      }
      if (kIsWeb) {
        await _auth.setPersistence(
          rememberMe ? Persistence.LOCAL : Persistence.SESSION,
        );
      }
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = credential.user;
      if (user != null && !user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } on FirebaseAuthException {
          // ignore: empty_catches
        }
        lastFailure = SignInFailure.emailNotVerified;
        await _auth.signOut();
        return false;
      }
      await _rememberSession(credential.user, email, rememberMe: rememberMe);

      return true;
    } on FirebaseAuthException {
      lastFailure = SignInFailure.invalidCredentials;
      return false;
    }
  }

  Future<void> _rememberSession(
    User? user,
    String email, {
    required bool rememberMe,
  }) async {
    if (user == null) return;

    if (!rememberMe) {
      await UserPreferences.clearSession();
      return;
    }

    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final fullName = snapshot.data()?['fullName'] as String? ?? '';

    await UserPreferences.setUserEmail(email);
    await UserPreferences.setFullName(fullName);
    await UserPreferences.setRememberMe(true);
  }

  Future<bool> signOut() async {
    final uid = _auth.currentUser?.uid;
    try {
      await _push.stop(ownerUid: uid);
    } catch (_) {
      return false;
    }
    try {
      await _auth.signOut();
      await UserPreferences.endSession();
      FirebaseServices.invalidateCache();

      await ProfileImageCache.clear();
      return true;
    } catch (_) {
      if (_auth.currentUser?.uid == uid) {
        try {
          await _push.startIfEnabled(expectedUid: uid);
        } catch (_) {}
      }
      return false;
    }
  }
}
