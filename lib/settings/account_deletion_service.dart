import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/login/user_preferences.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReauthenticationFailure implements Exception {
  const ReauthenticationFailure();
}

class AccountDeletionService {
  AccountDeletionService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw StateError('No signed-in user to delete.');
    }

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
    await _deleteCollection(
      _firestore.collection('users').doc(uid).collection('notes'),
    );
    await _deleteCollection(
      _firestore.collection('notes').doc(uid).collection('userNotes'),
    );
    await _firestore.collection('notes').doc(uid).delete();

    await _deleteParticipationRecords(uid);

    await _firestore.collection('users').doc(uid).delete();
  }

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
