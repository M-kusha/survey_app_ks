import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NoteBody {
  const NoteBody({required this.controller, this.error});

  final quill.QuillController controller;

  final String? error;

  bool get failed => error != null;
}

class NotesBackend {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId => _auth.currentUser!.uid;

  DocumentReference getNoteDocumentReference(String noteId) => _firestore
      .collection('users')
      .doc(_userId)
      .collection('notes')
      .doc(noteId);

  DocumentReference _rowRef(String noteId) => _firestore
      .collection('notes')
      .doc(_userId)
      .collection('userNotes')
      .doc(noteId);

  Future<NoteBody> loadNote(String noteId) async {
    try {
      final snapshot = await getNoteDocumentReference(noteId).get();
      final data = snapshot.data() as Map<String, dynamic>?;
      final content = data?['content'] as List<dynamic>?;

      return NoteBody(
        controller: quill.QuillController(
          document: content == null
              ? quill.Document()
              : quill.Document.fromJson(content),
          selection: const TextSelection.collapsed(offset: 0),
        ),
      );
    } catch (e) {
      return NoteBody(controller: quill.QuillController.basic(), error: '$e');
    }
  }

  Future<void> saveNote(String noteId, quill.QuillController controller) async {
    final batch = _firestore.batch();

    batch.set(getNoteDocumentReference(noteId), {
      'content': controller.document.toDelta().toJson(),
    }, SetOptions(merge: true));

    batch.set(_rowRef(noteId), {
      'preview': previewOf(controller.document.toPlainText()),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
}

String previewOf(String plainText, {int max = 160}) {
  final flattened = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flattened.length <= max ? flattened : flattened.substring(0, max);
}
