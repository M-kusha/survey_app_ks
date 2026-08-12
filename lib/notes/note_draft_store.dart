import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NoteDraft {
  const NoteDraft({
    required this.title,
    required this.content,
    required this.baseRevision,
    required this.baseUpdatedAtMillis,
    required this.savedAtMillis,
  });

  final String title;
  final List<dynamic> content;
  final int? baseRevision;
  final int? baseUpdatedAtMillis;
  final int savedAtMillis;

  Map<String, dynamic> toJson() => {
    'version': 2,
    'title': title,
    'content': content,
    'baseRevision': baseRevision,
    'baseUpdatedAtMillis': baseUpdatedAtMillis,
    'savedAtMillis': savedAtMillis,
  };

  static NoteDraft? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;

    final title = value['title'];
    final content = value['content'];
    if (title is! String || content is! List<dynamic>) return null;

    if (value['version'] == 1) {
      return NoteDraft(
        title: title,
        content: content,
        baseRevision: null,
        baseUpdatedAtMillis: null,
        savedAtMillis: 0,
      );
    }
    if (value['version'] != 2) return null;

    final baseRevision = value['baseRevision'];
    final baseUpdatedAtMillis = value['baseUpdatedAtMillis'];
    final savedAtMillis = value['savedAtMillis'];
    if (baseRevision != null && baseRevision is! int) return null;
    if (baseUpdatedAtMillis != null && baseUpdatedAtMillis is! int) return null;
    if (savedAtMillis is! int) return null;

    return NoteDraft(
      title: title,
      content: content,
      baseRevision: baseRevision as int?,
      baseUpdatedAtMillis: baseUpdatedAtMillis as int?,
      savedAtMillis: savedAtMillis,
    );
  }

  bool isSafeToAutoRestore({
    required int cloudRevision,
    required int? cloudUpdatedAtMillis,
  }) {
    final base = baseRevision;
    if (base == null || base != cloudRevision) return false;
    return baseUpdatedAtMillis == cloudUpdatedAtMillis;
  }
}

class PendingNoteDeletion {
  const PendingNoteDeletion({
    required this.noteId,
    required this.finalizeAfterMillis,
    this.undoRequested = false,
    this.deleteConfirmed = false,
  });

  final String noteId;
  final int finalizeAfterMillis;
  final bool undoRequested;
  final bool deleteConfirmed;

  PendingNoteDeletion requestUndo() => PendingNoteDeletion(
    noteId: noteId,
    finalizeAfterMillis: finalizeAfterMillis,
    undoRequested: true,
    deleteConfirmed: false,
  );

  PendingNoteDeletion confirmDelete() => PendingNoteDeletion(
    noteId: noteId,
    finalizeAfterMillis: finalizeAfterMillis,
    deleteConfirmed: true,
  );

  Map<String, dynamic> toJson() => {
    'version': 1,
    'noteId': noteId,
    'finalizeAfterMillis': finalizeAfterMillis,
    'undoRequested': undoRequested,
    'deleteConfirmed': deleteConfirmed,
  };

  static PendingNoteDeletion? fromJson(Object? value) {
    if (value is! Map<String, dynamic> || value['version'] != 1) return null;
    final noteId = value['noteId'];
    final finalizeAfterMillis = value['finalizeAfterMillis'];
    final undoRequested = value['undoRequested'];
    final deleteConfirmed = value['deleteConfirmed'] ?? false;
    if (noteId is! String ||
        noteId.isEmpty ||
        finalizeAfterMillis is! int ||
        undoRequested is! bool ||
        deleteConfirmed is! bool) {
      return null;
    }
    return PendingNoteDeletion(
      noteId: noteId,
      finalizeAfterMillis: finalizeAfterMillis,
      undoRequested: undoRequested,
      deleteConfirmed: deleteConfirmed,
    );
  }
}

class NoteDraftStore {
  NoteDraftStore({String? userId})
    : _userId = userId ?? FirebaseAuth.instance.currentUser!.uid;

  final String _userId;

  String _key(String noteId) => 'note-draft-v1:$_userId:$noteId';
  String get _deletionPrefix => 'note-delete-v1:$_userId:';
  String _deletionKey(String noteId) => '$_deletionPrefix$noteId';

  Future<NoteDraft?> load(String noteId) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_key(noteId));
    if (encoded == null) return null;

    try {
      final draft = NoteDraft.fromJson(jsonDecode(encoded));
      if (draft != null) return draft;
    } on FormatException {
      // ignore: empty_catches
    }

    await preferences.remove(_key(noteId));
    return null;
  }

  Future<void> save(String noteId, NoteDraft draft) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _key(noteId),
      jsonEncode(draft.toJson()),
    );
    if (!saved) throw StateError('The local note recovery copy was not saved.');
  }

  Future<void> remove(String noteId) async {
    final preferences = await SharedPreferences.getInstance();
    final removed = await preferences.remove(_key(noteId));
    if (!removed && preferences.containsKey(_key(noteId))) {
      throw StateError('The local note recovery copy was not removed.');
    }
  }

  Future<void> saveDeletion(PendingNoteDeletion deletion) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(
      _deletionKey(deletion.noteId),
      jsonEncode(deletion.toJson()),
    );
    if (!saved) throw StateError('The pending note deletion was not saved.');
  }

  Future<List<PendingNoteDeletion>> loadDeletions() async {
    final preferences = await SharedPreferences.getInstance();
    final deletions = <PendingNoteDeletion>[];
    for (final key in preferences.getKeys()) {
      if (!key.startsWith(_deletionPrefix)) continue;
      final encoded = preferences.getString(key);
      PendingNoteDeletion? deletion;
      try {
        deletion = encoded == null
            ? null
            : PendingNoteDeletion.fromJson(jsonDecode(encoded));
      } on FormatException {
        deletion = null;
      }
      if (deletion == null) {
        await preferences.remove(key);
      } else {
        deletions.add(deletion);
      }
    }
    return deletions;
  }

  Future<void> removeDeletion(String noteId) async {
    final preferences = await SharedPreferences.getInstance();
    final key = _deletionKey(noteId);
    final removed = await preferences.remove(key);
    if (!removed && preferences.containsKey(key)) {
      throw StateError('The pending note deletion was not removed.');
    }
  }
}
