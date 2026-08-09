import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:echomeet/core/notifications/push_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthManager {
  AuthManager({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _authOverride = auth,
      _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  late final FirebaseAuth _auth = _authOverride ?? FirebaseAuth.instance;
  late final FirebaseFirestore _firestore =
      _firestoreOverride ?? FirebaseFirestore.instance;

  Future<bool> signInWithEmailAndPassword(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      await _rememberSession(credential.user, email, rememberMe: rememberMe);

      unawaited(PushService().start());
      return true;
    } on FirebaseAuthException {
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

  Future<void> signOut() async {
    await PushService().stop();
    await _auth.signOut();
    await UserPreferences.clearSession();
    FirebaseServices.invalidateCache();
  }
}
