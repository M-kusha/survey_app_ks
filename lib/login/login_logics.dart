// auth_manager.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:survey_app_ks/login/user_preferences.dart';

class AuthManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<bool> signInWithEmailAndPassword(
      String email, String password, bool rememberMe, userData) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _handleLoginSuccess(
        email,
        password,
        rememberMe,
      );
      return true;
    } on FirebaseAuthException {
      return false;
    }
  }

  Future<void> _handleLoginSuccess(
      String email, String password, bool rememberMe) async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

      String fullName = userData['fullName'];

      UserPreferences.setUserEmail(email);
      UserPreferences.setUserPassword(password);
      UserPreferences.setFullName(fullName);
      UserPreferences.setRememberMe(rememberMe);
    }
  }
}
