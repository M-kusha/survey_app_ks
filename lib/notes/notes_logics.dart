import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> renameNote(String noteId, String title) async {
    await userNotesCollection.doc(noteId).update({'title': title});
  }

  Future<void> restoreNote({
    required String title,
    required bool completed,
  }) async {
    await userNotesCollection.add({
      'title': title,
      'completed': completed,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteNote(String noteId) async {
    await userNotesCollection.doc(noteId).delete();

    await _bodyRef(noteId).delete().catchError((_) {});
  }

  Future<void> setCompleted(String noteId, bool completed) async {
    await userNotesCollection.doc(noteId).update({'completed': completed});
  }
}
