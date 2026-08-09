import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class NoteBody {
  const NoteBody({
    required this.controller,
    required this.revision,
    this.updatedAt,
    this.title,
    this.error,
  });

  final quill.QuillController controller;
  final int revision;
  final DateTime? updatedAt;
  final String? title;

  final String? error;

  bool get failed => error != null;
}

class NoteSaveResult {
  const NoteSaveResult({required this.revision, required this.updatedAt});

  final int revision;
  final DateTime updatedAt;
}

class NoteRevisionConflictException implements Exception {
  const NoteRevisionConflictException({
    required this.cloudRevision,
    required this.cloudUpdatedAt,
  });

  final int cloudRevision;
  final DateTime? cloudUpdatedAt;
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
      final bodyRef = getNoteDocumentReference(noteId);
      final rowRef = _rowRef(noteId);
      final loaded = await _firestore.runTransaction((transaction) async {
        final body = await transaction.get(bodyRef);
        final row = await transaction.get(rowRef);
        return (
          body.data() as Map<String, dynamic>?,
          row.data() as Map<String, dynamic>?,
        );
      });
      final (bodyData, rowData) = loaded;
      final content = bodyData?['content'] as List<dynamic>?;
      final revision = bodyData?['revision'] as int? ?? 0;
      final updatedAt =
          (rowData?['updatedAt'] as Timestamp?) ??
          (bodyData?['updatedAt'] as Timestamp?);

      return NoteBody(
        controller: quill.QuillController(
          document: content == null
              ? quill.Document()
              : quill.Document.fromJson(content),
          selection: const TextSelection.collapsed(offset: 0),
        ),
        revision: revision,
        updatedAt: updatedAt?.toDate(),
        title: rowData?['title'] as String?,
      );
    } catch (e) {
      return NoteBody(
        controller: quill.QuillController.basic(),
        revision: 0,
        error: '$e',
      );
    }
  }

  Future<NoteSaveResult> saveNote(
    String noteId, {
    required String title,
    required List<dynamic> content,
    required String plainText,
    required int expectedRevision,
    required DateTime? expectedUpdatedAt,
  }) {
    final bodyRef = getNoteDocumentReference(noteId);
    final rowRef = _rowRef(noteId);

    return _firestore.runTransaction((transaction) async {
      final bodySnapshot = await transaction.get(bodyRef);
      final rowSnapshot = await transaction.get(rowRef);
      final bodyData = bodySnapshot.data() as Map<String, dynamic>?;
      final rowData = rowSnapshot.data() as Map<String, dynamic>?;
      final cloudRevision = bodyData?['revision'] as int? ?? 0;
      final cloudTimestamp =
          (rowData?['updatedAt'] as Timestamp?) ??
          (bodyData?['updatedAt'] as Timestamp?);
      final cloudUpdatedAt = cloudTimestamp?.toDate();
      final timestampChanged =
          cloudUpdatedAt?.millisecondsSinceEpoch !=
          expectedUpdatedAt?.millisecondsSinceEpoch;

      if (!rowSnapshot.exists ||
          cloudRevision != expectedRevision ||
          timestampChanged) {
        throw NoteRevisionConflictException(
          cloudRevision: cloudRevision,
          cloudUpdatedAt: cloudUpdatedAt,
        );
      }

      final nextRevision = cloudRevision + 1;
      final updatedAt = Timestamp.now();
      transaction.set(bodyRef, {
        'content': content,
        'revision': nextRevision,
        'updatedAt': updatedAt,
      }, SetOptions(merge: true));
      transaction.set(rowRef, {
        'title': title,
        'preview': previewOf(plainText),
        'updatedAt': updatedAt,
        'revision': nextRevision,
      }, SetOptions(merge: true));

      return NoteSaveResult(
        revision: nextRevision,
        updatedAt: updatedAt.toDate(),
      );
    });
  }
}

String previewOf(String plainText, {int max = 160}) {
  final flattened = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
  return flattened.length <= max ? flattened : flattened.substring(0, max);
}
