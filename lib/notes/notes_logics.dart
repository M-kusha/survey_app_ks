import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TodoListBackend {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get userToken => _auth.currentUser!.uid;

  CollectionReference get userNotesCollection => FirebaseFirestore.instance
      .collection('notes')
      .doc(userToken)
      .collection('userNotes');

  Future<void> addNoteItem(String title) async {
    await userNotesCollection.add({
      'title': title,
      'completed': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void deleteNotesItem(DocumentReference docRef) {
    docRef.delete();
  }

  void completeNotesItem(DocumentReference docRef, bool completed) {
    docRef.update({'completed': !completed});
  }
}
