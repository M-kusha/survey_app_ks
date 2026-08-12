import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum NoteDeletionFinalization { deleted, cancelled, notReady }

class TodoListBackend {
  late final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get userToken => _auth.currentUser!.uid;

  CollectionReference get userNotesCollection =>
      _firestore.collection('notes').doc(userToken).collection('userNotes');

  DocumentReference _bodyRef(String noteId) => _firestore
      .collection('users')
      .doc(userToken)
      .collection('notes')
      .doc(noteId);

  Future<String> addNoteItem(String title) async {
    final document = await userNotesCollection.add({
      'title': title,
      'completed': false,
      'pinned': false,

      'preview': '',
      'timestamp': FieldValue.serverTimestamp(),
    });

    return document.id;
  }

  Future<void> setPinned(String noteId, bool pinned) async {
    await userNotesCollection.doc(noteId).update({'pinned': pinned});
  }

  Future<void> stageNoteDeletion(
    String noteId, {
    required DateTime finalizeAfter,
  }) async {
    await userNotesCollection.doc(noteId).update({
      'deletionPendingAt': FieldValue.serverTimestamp(),
      'deletionFinalizeAfter': Timestamp.fromDate(finalizeAfter),
    });
  }

  Future<bool> undoNoteDeletion(String noteId) {
    final rowRef = userNotesCollection.doc(noteId);
    return _firestore.runTransaction((transaction) async {
      final row = await transaction.get(rowRef);
      if (!row.exists) return false;
      final data = row.data() as Map<String, dynamic>? ?? const {};
      if (data['deletionPendingAt'] == null) return true;
      transaction.update(rowRef, {
        'deletionPendingAt': FieldValue.delete(),
        'deletionFinalizeAfter': FieldValue.delete(),
      });
      return true;
    });
  }

  Future<NoteDeletionFinalization> finalizeNoteDeletion(
    String noteId, {
    bool ignoreGracePeriod = false,
  }) {
    final rowRef = userNotesCollection.doc(noteId);
    final bodyRef = _bodyRef(noteId);
    return _firestore.runTransaction((transaction) async {
      final row = await transaction.get(rowRef);
      if (!row.exists) {
        transaction.delete(bodyRef);
        return NoteDeletionFinalization.deleted;
      }

      final data = row.data() as Map<String, dynamic>? ?? const {};
      final pending = data['deletionPendingAt'] != null;
      final finalizeAfter = data['deletionFinalizeAfter'] as Timestamp?;
      if (!pending || finalizeAfter == null) {
        return NoteDeletionFinalization.cancelled;
      }
      if (!ignoreGracePeriod &&
          finalizeAfter.toDate().isAfter(DateTime.now())) {
        return NoteDeletionFinalization.notReady;
      }

      transaction.delete(rowRef);
      transaction.delete(bodyRef);
      return NoteDeletionFinalization.deleted;
    });
  }

  Future<void> setCompleted(String noteId, bool completed) async {
    await userNotesCollection.doc(noteId).update({'completed': completed});
  }
}
