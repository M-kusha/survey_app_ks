import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sign-in and sign-out.
class AuthManager {
  AuthManager({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Returns true when the credentials were accepted.
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
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  /// Records just enough to greet the user by name next launch.
  ///
  /// Only the email and display name are kept — never the password.
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

    // A missing or malformed profile document must not fail a sign-in that
    // Firebase already accepted, so the name is read defensively.
    final snapshot = await _firestore.collection('users').doc(user.uid).get();
    final fullName = snapshot.data()?['fullName'] as String? ?? '';

    await UserPreferences.setUserEmail(email);
    await UserPreferences.setFullName(fullName);
    await UserPreferences.setRememberMe(true);
  }

  /// Ends the session and forgets the signed-in user.
  ///
  /// The cached profile must be dropped too, otherwise the next user to sign in
  /// on this device would inherit the previous user's role and company.
  Future<void> signOut() async {
    await _auth.signOut();
    await UserPreferences.clearSession();
    FirebaseServices.invalidateCache();
  }
}
