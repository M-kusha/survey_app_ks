import 'dart:async';

import 'package:echomeet/login/user_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SessionAccess extends ChangeNotifier {
  SessionAccess({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance {
    final currentUser = _auth.currentUser;
    _userId = currentUser?.uid;

    _isUnlocked =
        currentUser?.emailVerified == true &&
        !UserPreferences.getBiometricAuthEnabled();
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (!_handledInitialAuthState) {
        _handledInitialAuthState = true;
        _userId = user?.uid;
        _setUnlocked(
          user?.emailVerified == true &&
              !UserPreferences.getBiometricAuthEnabled(),
        );
        return;
      }
      if (user?.uid == _userId) return;
      _userId = user?.uid;
      lock();
    });
  }

  final FirebaseAuth _auth;
  StreamSubscription<User?>? _authSubscription;
  String? _userId;
  bool _isUnlocked = false;
  bool _handledInitialAuthState = false;
  bool _disposed = false;

  bool get isUnlocked => _isUnlocked;

  void unlock() {
    _setUnlocked(true);
  }

  void lock() {
    _setUnlocked(false);
  }

  void _setUnlocked(bool value) {
    if (_disposed || _isUnlocked == value) return;
    _isUnlocked = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
