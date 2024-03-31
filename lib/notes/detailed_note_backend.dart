import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NotesBackend {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId => _auth.currentUser!.uid;

  DocumentReference getNoteDocumentReference(String noteId) {
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('notes')
        .doc(noteId);
  }

  Future<quill.QuillController> loadNoteController(String noteId) async {
    final docRef = getNoteDocumentReference(noteId);
    final docSnapshot = await docRef.get();

    if (docSnapshot.exists && docSnapshot.data() != null) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final content = data['content'] as List<dynamic>?;
      return quill.QuillController(
          document: content != null
              ? quill.Document.fromJson(content)
              : quill.Document(),
          selection: const TextSelection.collapsed(offset: 0));
    }

    return quill.QuillController.basic();
  }

  Future<void> saveNote(String noteId, quill.QuillController controller) async {
    final content = controller.document.toDelta().toJson();
    await getNoteDocumentReference(noteId)
        .set({'content': content}, SetOptions(merge: true));
  }
}
