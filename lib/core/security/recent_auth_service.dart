import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum RecentAuthenticationFailure {
  invalidCredential,
  accountUnavailable,
  unavailable,
}

@immutable
class RecentAuthenticationException implements Exception {
  const RecentAuthenticationException(this.failure);

  final RecentAuthenticationFailure failure;
}

@visibleForTesting
Future<void> performRecentPasswordAuthentication({
  required String email,
  required String password,
  required Future<void> Function(AuthCredential credential) reauthenticate,
  required Future<void> Function() forceTokenRefresh,
}) async {
  if (email.trim().isEmpty) {
    throw const RecentAuthenticationException(
      RecentAuthenticationFailure.accountUnavailable,
    );
  }
  if (password.isEmpty) {
    throw const RecentAuthenticationException(
      RecentAuthenticationFailure.invalidCredential,
    );
  }

  try {
    await reauthenticate(
      EmailAuthProvider.credential(email: email, password: password),
    );
  } on FirebaseAuthException catch (error) {
    throw RecentAuthenticationException(switch (error.code) {
      'wrong-password' ||
      'invalid-credential' => RecentAuthenticationFailure.invalidCredential,
      'user-disabled' ||
      'user-not-found' ||
      'invalid-user-token' ||
      'user-token-expired' => RecentAuthenticationFailure.accountUnavailable,
      _ => RecentAuthenticationFailure.unavailable,
    });
  } catch (_) {
    throw const RecentAuthenticationException(
      RecentAuthenticationFailure.unavailable,
    );
  }

  try {
    await forceTokenRefresh();
  } on FirebaseAuthException catch (error) {
    throw RecentAuthenticationException(switch (error.code) {
      'user-disabled' ||
      'user-not-found' ||
      'invalid-user-token' ||
      'user-token-expired' => RecentAuthenticationFailure.accountUnavailable,
      _ => RecentAuthenticationFailure.unavailable,
    });
  } catch (_) {
    throw const RecentAuthenticationException(
      RecentAuthenticationFailure.unavailable,
    );
  }
}

class RecentAuthService {
  RecentAuthService({FirebaseAuth? auth}) : _providedAuth = auth;

  final FirebaseAuth? _providedAuth;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  Future<void> confirmPassword(String password) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const RecentAuthenticationException(
        RecentAuthenticationFailure.accountUnavailable,
      );
    }

    await performRecentPasswordAuthentication(
      email: email,
      password: password,
      reauthenticate: user.reauthenticateWithCredential,
      forceTokenRefresh: () async {
        await user.getIdToken(true);
      },
    );
  }
}
