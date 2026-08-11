import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

typedef EmailCurrentAddressReader = String? Function();
typedef EmailRecentPasswordAuthenticator =
    Future<void> Function(String password);
typedef EmailVerificationRequester =
    Future<void> Function(String expectedCurrentEmail, String newEmail);
typedef VerifiedEmailPreparer = Future<String> Function();
typedef VerifiedEmailReader = Future<String> Function();
typedef SyncVerifiedEmailCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

enum EmailChangeFailure {
  invalidEmail,
  unchangedEmail,
  invalidCredential,
  emailAlreadyInUse,
  recentLoginRequired,
  accountUnavailable,
  emailNotVerified,
  verificationPending,
  unavailable,
}

@immutable
class EmailChangeException implements Exception {
  const EmailChangeException(this.failure);

  final EmailChangeFailure failure;
}

@immutable
class EmailChangeRequestReceipt {
  const EmailChangeRequestReceipt({required this.newEmail});

  final String newEmail;
}

@immutable
class EmailSyncReceipt {
  const EmailSyncReceipt({required this.changed});

  final bool changed;
}

class EmailChangeService {
  EmailChangeService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    RecentAuthService? recentAuth,
    EmailCurrentAddressReader? currentAddressReader,
    EmailRecentPasswordAuthenticator? recentPasswordAuthenticator,
    EmailVerificationRequester? verificationRequester,
    VerifiedEmailPreparer? verifiedEmailPreparer,
    VerifiedEmailReader? verifiedEmailReader,
    SyncVerifiedEmailCallable? syncVerifiedEmailCallable,
  }) : _providedAuth = auth,
       _currentAddressReader = currentAddressReader,
       _authenticate =
           recentPasswordAuthenticator ??
           (recentAuth ?? RecentAuthService(auth: auth)).confirmPassword,
       _verificationRequester = verificationRequester,
       _verifiedEmailPreparer = verifiedEmailPreparer,
       _verifiedEmailReader = verifiedEmailReader,
       _syncVerifiedEmail =
           syncVerifiedEmailCallable ??
           ((payload) => _firebaseSyncVerifiedEmail(functions, payload));

  static const maxEmailLength = 254;
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final FirebaseAuth? _providedAuth;
  final EmailCurrentAddressReader? _currentAddressReader;
  final EmailRecentPasswordAuthenticator _authenticate;
  final EmailVerificationRequester? _verificationRequester;
  final VerifiedEmailPreparer? _verifiedEmailPreparer;
  final VerifiedEmailReader? _verifiedEmailReader;
  final SyncVerifiedEmailCallable _syncVerifiedEmail;

  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;

  static String normalizeEmail(String value) => value.trim().toLowerCase();

  static bool isValidEmail(String value) {
    final email = normalizeEmail(value);
    return email.isNotEmpty &&
        email.length <= maxEmailLength &&
        _emailPattern.hasMatch(email);
  }

  Future<EmailChangeRequestReceipt> requestChange({
    required String newEmail,
    required String password,
  }) async {
    final normalizedNewEmail = normalizeEmail(newEmail);
    if (!isValidEmail(normalizedNewEmail)) {
      throw const EmailChangeException(EmailChangeFailure.invalidEmail);
    }

    final currentEmail = normalizeEmail(
      (_currentAddressReader ?? () => _auth.currentUser?.email).call() ?? '',
    );
    if (!isValidEmail(currentEmail)) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    if (currentEmail == normalizedNewEmail) {
      throw const EmailChangeException(EmailChangeFailure.unchangedEmail);
    }

    try {
      await _authenticate(password);
    } on RecentAuthenticationException catch (error) {
      throw EmailChangeException(switch (error.failure) {
        RecentAuthenticationFailure.invalidCredential =>
          EmailChangeFailure.invalidCredential,
        RecentAuthenticationFailure.accountUnavailable =>
          EmailChangeFailure.accountUnavailable,
        RecentAuthenticationFailure.unavailable =>
          EmailChangeFailure.unavailable,
      });
    } catch (_) {
      throw const EmailChangeException(EmailChangeFailure.unavailable);
    }

    try {
      final requester = _verificationRequester ?? _requestFirebaseVerification;
      await requester(currentEmail, normalizedNewEmail);
    } on EmailChangeException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw EmailChangeException(_requestFailureFor(error));
    } catch (_) {
      throw const EmailChangeException(EmailChangeFailure.unavailable);
    }

    return EmailChangeRequestReceipt(newEmail: normalizedNewEmail);
  }

  /// Reloads Firebase Auth, requires its current address to be verified, forces
  /// a fresh ID token, then copies that trusted address through the callable.
  Future<EmailSyncReceipt> syncVerifiedEmail({String? expectedEmail}) async {
    final String currentEmail;
    try {
      currentEmail = await (_verifiedEmailPreparer ?? _prepareFirebaseEmail)();
    } on EmailChangeException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw EmailChangeException(_authFailureFor(error));
    } catch (_) {
      throw const EmailChangeException(EmailChangeFailure.unavailable);
    }
    return _syncPreparedEmail(currentEmail, expectedEmail: expectedEmail);
  }

  /// Used only after a caller has already reloaded Auth and forced a token.
  /// The verified-address check is repeated before the callable is invoked.
  Future<EmailSyncReceipt> syncAfterAuthenticationRefresh({
    String? expectedEmail,
  }) async {
    final String currentEmail;
    try {
      currentEmail = await (_verifiedEmailReader ?? _readFirebaseEmail)();
    } on EmailChangeException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw EmailChangeException(_authFailureFor(error));
    } catch (_) {
      throw const EmailChangeException(EmailChangeFailure.unavailable);
    }
    return _syncPreparedEmail(currentEmail, expectedEmail: expectedEmail);
  }

  Future<EmailSyncReceipt> _syncPreparedEmail(
    String currentEmail, {
    String? expectedEmail,
  }) async {
    final normalizedCurrentEmail = normalizeEmail(currentEmail);
    if (!isValidEmail(normalizedCurrentEmail)) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    if (expectedEmail != null) {
      final normalizedExpectedEmail = normalizeEmail(expectedEmail);
      if (!isValidEmail(normalizedExpectedEmail)) {
        throw const EmailChangeException(EmailChangeFailure.invalidEmail);
      }
      if (normalizedExpectedEmail != normalizedCurrentEmail) {
        throw const EmailChangeException(
          EmailChangeFailure.verificationPending,
        );
      }
    }

    final Map<String, dynamic> data;
    try {
      data = await _syncVerifiedEmail(const <String, dynamic>{});
    } on FirebaseFunctionsException catch (error) {
      throw EmailChangeException(_syncFailureFor(error));
    } catch (_) {
      throw const EmailChangeException(EmailChangeFailure.unavailable);
    }

    if (!setEquals(data.keys.toSet(), const {'synced', 'changed'}) ||
        data['synced'] != true ||
        data['changed'] is! bool) {
      throw const EmailChangeException(EmailChangeFailure.unavailable);
    }
    return EmailSyncReceipt(changed: data['changed'] as bool);
  }

  Future<void> _requestFirebaseVerification(
    String expectedCurrentEmail,
    String newEmail,
  ) async {
    final user = _auth.currentUser;
    final currentEmail = normalizeEmail(user?.email ?? '');
    if (user == null || currentEmail != expectedCurrentEmail) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  Future<String> _prepareFirebaseEmail() async {
    final initialUser = _auth.currentUser;
    if (initialUser == null) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    final uid = initialUser.uid;
    await initialUser.reload();
    final refreshedUser = _auth.currentUser;
    if (refreshedUser == null || refreshedUser.uid != uid) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    final email = _verifiedEmailFrom(refreshedUser);
    await refreshedUser.getIdToken(true);
    return email;
  }

  Future<String> _readFirebaseEmail() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    return _verifiedEmailFrom(user);
  }

  static String _verifiedEmailFrom(User user) {
    if (!user.emailVerified) {
      throw const EmailChangeException(EmailChangeFailure.emailNotVerified);
    }
    final email = normalizeEmail(user.email ?? '');
    if (!isValidEmail(email)) {
      throw const EmailChangeException(EmailChangeFailure.accountUnavailable);
    }
    return email;
  }

  static Future<Map<String, dynamic>> _firebaseSyncVerifiedEmail(
    FirebaseFunctions? functions,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await (functions ??
                FirebaseFunctions.instanceFor(region: 'europe-west4'))
            .httpsCallable(
              'syncVerifiedEmail',
              options: HttpsCallableOptions(
                timeout: const Duration(seconds: 30),
              ),
            )
            .call<Map<String, dynamic>>(payload);
    return result.data;
  }

  static EmailChangeFailure _requestFailureFor(FirebaseAuthException error) =>
      switch (error.code) {
        'invalid-email' => EmailChangeFailure.invalidEmail,
        'email-already-in-use' => EmailChangeFailure.emailAlreadyInUse,
        'requires-recent-login' => EmailChangeFailure.recentLoginRequired,
        'user-disabled' ||
        'user-not-found' ||
        'invalid-user-token' ||
        'user-token-expired' => EmailChangeFailure.accountUnavailable,
        _ => EmailChangeFailure.unavailable,
      };

  static EmailChangeFailure _authFailureFor(FirebaseAuthException error) =>
      switch (error.code) {
        'user-disabled' ||
        'user-not-found' ||
        'invalid-user-token' ||
        'user-token-expired' => EmailChangeFailure.accountUnavailable,
        _ => EmailChangeFailure.unavailable,
      };

  static EmailChangeFailure _syncFailureFor(FirebaseFunctionsException error) {
    final key = '${error.code}/${error.message}';
    return switch (key) {
      'unauthenticated/authentication-required' =>
        EmailChangeFailure.accountUnavailable,
      'failed-precondition/email-not-verified' =>
        EmailChangeFailure.emailNotVerified,
      'failed-precondition/email-sync-account-unavailable' ||
      'failed-precondition/email-sync-profile-missing' =>
        EmailChangeFailure.accountUnavailable,
      'failed-precondition/account-deletion-started' =>
        EmailChangeFailure.unavailable,
      _ => EmailChangeFailure.unavailable,
    };
  }
}
