import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/notifications/push_service.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReauthenticationFailure implements Exception {
  const ReauthenticationFailure();
}

class OwnerAccountDeletionBlocked implements Exception {
  const OwnerAccountDeletionBlocked();
}

class AccountDeletionIncomplete implements Exception {
  const AccountDeletionIncomplete();
}

class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFunctions? functions})
    : _auth = auth ?? FirebaseAuth.instance,
      _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'europe-west4');

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  Future<void> deleteAccount({
    required String password,
    bool deleteOwnedCompany = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user to delete.');
    }

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      // Force the callable to receive the new auth_time claim rather than an
      // older cached ID token. The server independently enforces a five-minute
      // recent-login window and checks company ownership from Firestore.
      await user.getIdToken(true);
    } on FirebaseAuthException {
      throw const ReauthenticationFailure();
    }

    try {
      final callable = _functions.httpsCallable(
        'deleteMyAccount',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 9)),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'deleteOwnedCompany': deleteOwnedCompany,
      });
      if (result.data['deleted'] != true) {
        throw const AccountDeletionIncomplete();
      }
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'failed-precondition' &&
          error.message == 'company-owner') {
        throw const OwnerAccountDeletionBlocked();
      }
      if (error.code == 'failed-precondition' &&
          error.message == 'recent-login-required') {
        throw const ReauthenticationFailure();
      }
      throw const AccountDeletionIncomplete();
    }

    // The trusted function has now removed personal data and deleted Auth last.
    // Local token/session cleanup cannot make that completed deletion partial.
    try {
      await PushService().stop();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}

    await UserPreferences.clearSession();
    FirebaseServices.invalidateCache();
  }
}
