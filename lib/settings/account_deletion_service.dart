import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Raised when the password given for re-authentication is not accepted.
class ReauthenticationFailure implements Exception {
  const ReauthenticationFailure();
}

/// Deletes the signed-in user's account and the data that belongs to them.
///
/// What counts as "theirs" matters here. A user's profile, notes and survey or
/// appointment *responses* are personal and go with them. The surveys and
/// appointments themselves belong to the company, so they stay — an admin
/// leaving must not take the company's content with them. An earlier version
/// tried to delete whole `surveys` and `appointments` documents, though it
/// matched them on a `userId` field that those documents have never had, so in
/// practice it deleted nothing at all and left the auth account intact.
class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Re-authenticates with [password], erases the user's data, then deletes the
  /// account itself.
  ///
  /// Firestore data is removed *before* the auth account, because the security
  /// rules that authorise those deletes depend on being signed in. If the run
  /// fails part-way the account still exists, so the user can try again.
  ///
  /// Throws [ReauthenticationFailure] if the password is wrong.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user to delete.');
    }

    // Firebase refuses to delete an account whose sign-in is not recent, so
    // this both satisfies that requirement and confirms intent.
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
    } on FirebaseAuthException {
      throw const ReauthenticationFailure();
    }

    await _deleteUserData(user.uid);
    await user.delete();

    await UserPreferences.clearSession();
    FirebaseServices.invalidateCache();
  }

  Future<void> _deleteUserData(String uid) async {
    // Everything below is addressed by path rather than found by query, so it
    // does not depend on an index and cannot silently match nothing.
    await _deleteCollection(
      _firestore.collection('users').doc(uid).collection('notes'),
    );
    await _deleteCollection(
      _firestore.collection('notes').doc(uid).collection('userNotes'),
    );
    await _firestore.collection('notes').doc(uid).delete();

    await _deleteParticipationRecords(uid);

    // The profile document goes last: rules key off the role it holds.
    await _firestore.collection('users').doc(uid).delete();
  }

  /// Removes the user's answers and RSVPs from every survey and appointment.
  ///
  /// These live in `participants` subcollections spread across documents this
  /// client cannot enumerate by path, so a collection-group query is the only
  /// way to reach them. It needs a composite index to be deployed; if that is
  /// missing the query throws, and the rest of the deletion still has to
  /// succeed, so the failure is contained rather than propagated.
  ///
  /// A Cloud Function triggered on account deletion is the robust version of
  /// this and is planned alongside the other server-side work.
  Future<void> _deleteParticipationRecords(String uid) async {
    try {
      final records = await _firestore
          .collectionGroup('participants')
          .where('userId', isEqualTo: uid)
          .get();

      await _commitInChunks(records.docs.map((d) => d.reference).toList());
    } on FirebaseException {
      return;
    }
  }

  Future<void> _deleteCollection(
    CollectionReference<Object?> collection,
  ) async {
    final snapshot = await collection.get();
    await _commitInChunks(snapshot.docs.map((d) => d.reference).toList());
  }

  /// Firestore caps a batch at 500 operations, so deletes are chunked.
  Future<void> _commitInChunks(List<DocumentReference<Object?>> refs) async {
    const chunkSize = 400;
    for (var i = 0; i < refs.length; i += chunkSize) {
      final batch = _firestore.batch();
      for (final ref in refs.skip(i).take(chunkSize)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }
}
