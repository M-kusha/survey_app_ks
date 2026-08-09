import 'package:echomeet/notes/note_draft_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('note draft recovery safety', () {
    const content = <dynamic>[
      {'insert': 'local text\n'},
    ];

    test('restores only when the authoritative revision is unchanged', () {
      const draft = NoteDraft(
        title: 'Local',
        content: content,
        baseRevision: 4,
        baseUpdatedAtMillis: 100,
        savedAtMillis: 200,
      );

      expect(
        draft.isSafeToAutoRestore(cloudRevision: 4, cloudUpdatedAtMillis: 100),
        isTrue,
      );
      expect(
        draft.isSafeToAutoRestore(cloudRevision: 4, cloudUpdatedAtMillis: 999),
        isFalse,
      );
      expect(
        draft.isSafeToAutoRestore(cloudRevision: 5, cloudUpdatedAtMillis: 1000),
        isFalse,
      );
    });

    test('legacy revision zero also requires the exact base timestamp', () {
      const draft = NoteDraft(
        title: 'Legacy base',
        content: content,
        baseRevision: 0,
        baseUpdatedAtMillis: 100,
        savedAtMillis: 200,
      );

      expect(
        draft.isSafeToAutoRestore(cloudRevision: 0, cloudUpdatedAtMillis: 100),
        isTrue,
      );
      expect(
        draft.isSafeToAutoRestore(cloudRevision: 0, cloudUpdatedAtMillis: 101),
        isFalse,
      );
    });

    test('version-one drafts stay recoverable but never auto-restore', () {
      final draft = NoteDraft.fromJson({
        'version': 1,
        'title': 'Old local copy',
        'content': content,
      });

      expect(draft, isNotNull);
      expect(
        draft!.isSafeToAutoRestore(
          cloudRevision: 0,
          cloudUpdatedAtMillis: null,
        ),
        isFalse,
      );
    });
  });

  test('pending deletion journal preserves the chosen action', () {
    const pending = PendingNoteDeletion(
      noteId: 'note-1',
      finalizeAfterMillis: 1234,
    );

    final undo = PendingNoteDeletion.fromJson(pending.requestUndo().toJson());
    final confirmed = PendingNoteDeletion.fromJson(
      pending.confirmDelete().toJson(),
    );

    expect(undo?.undoRequested, isTrue);
    expect(undo?.deleteConfirmed, isFalse);
    expect(confirmed?.undoRequested, isFalse);
    expect(confirmed?.deleteConfirmed, isTrue);
  });
}
