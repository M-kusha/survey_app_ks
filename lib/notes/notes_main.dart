import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/notes/add_item_widget.dart';
import 'package:echomeet/notes/detailed_notes.dart';
import 'package:echomeet/notes/note_draft_store.dart';
import 'package:echomeet/notes/note_query.dart';
import 'package:echomeet/notes/notes_logics.dart';
import 'package:flutter/material.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  TodoListState createState() => TodoListState();
}

class TodoListState extends State<TodoList> {
  final _backend = TodoListBackend();
  late final _localStore = NoteDraftStore();
  final _searchController = TextEditingController();

  StreamSubscription<QuerySnapshot>? _subscription;

  List<NoteItem> _notes = [];
  NoteFilter _filter = NoteFilter.all;
  NoteSort _sort = NoteSort.newest;
  bool _loading = true;
  String? _error;
  final Set<String> _activeUndoWindows = {};
  final Set<String> _cleanupInFlight = {};
  final Map<String, Timer> _cleanupTimers = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _listen();
    unawaited(_resumeDeletionJournal());
  }

  void _listen({bool showLoading = false}) {
    if (showLoading) {
      setState(() {
        _error = null;
        _loading = true;
      });
    }
    unawaited(_subscription?.cancel());
    _subscription = _backend.userNotesCollection.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        final notes = <NoteItem>[];
        for (final document in snapshot.docs) {
          final data = document.data() as Map<String, dynamic>;
          if (data['deletionPendingAt'] != null) {
            final finalizeAfter =
                (data['deletionFinalizeAfter'] as Timestamp?)?.toDate() ??
                DateTime.now();
            if (!_activeUndoWindows.contains(document.id)) {
              _scheduleCleanup(
                PendingNoteDeletion(
                  noteId: document.id,
                  finalizeAfterMillis: finalizeAfter.millisecondsSinceEpoch,
                ),
              );
            }
          } else {
            notes.add(_toNote(document));
          }
        }
        setState(() {
          _notes = notes;
          _error = null;
          _loading = false;
        });
      },

      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = '$error';
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }
    _searchController.dispose();
    super.dispose();
  }

  static NoteItem _toNote(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NoteItem(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      completed: (data['completed'] ?? false) as bool,

      preview: (data['preview'] ?? '') as String,
      pinned: (data['pinned'] ?? false) as bool,

      createdAt: (data['timestamp'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  List<NoteItem> get _visible => queryNotes(
    _notes,
    search: _searchController.text,
    filter: _filter,
    sort: _sort,
  );

  int get _openCount => _notes.where((note) => !note.completed).length;

  Future<void> _create() async {
    final note = await DialogUtils.displayAddNoteDialog(context, _backend);
    if (note == null || !mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            DetailedNotePage(noteId: note.id, title: note.title),
      ),
    );
  }

  void _open(NoteItem note) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DetailedNotePage(
          noteId: note.id,
          title: note.title,
          pinned: note.pinned,
        ),
      ),
    );
  }

  Future<void> _delete(NoteItem note) async {
    final deletion = PendingNoteDeletion(
      noteId: note.id,
      // Other devices wait long enough for an offline undo to synchronize.
      // This device finalizes immediately when the Snackbar times out.
      finalizeAfterMillis: DateTime.now()
          .add(const Duration(minutes: 5))
          .millisecondsSinceEpoch,
    );
    _activeUndoWindows.add(note.id);
    try {
      await _localStore.saveDeletion(deletion);
      await _backend.stageNoteDeletion(
        note.id,
        finalizeAfter: DateTime.fromMillisecondsSinceEpoch(
          deletion.finalizeAfterMillis,
        ),
      );
    } catch (_) {
      _activeUndoWindows.remove(note.id);
      await _localStore.removeDeletion(note.id).catchError((_) {});
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
      }
      return;
    }
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    Future<void>? undo;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text('note_deleted'.tr()),

        showCloseIcon: true,
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'undo'.tr(),
          onPressed: () {
            undo = _undoDeletion(deletion);
          },
        ),
      ),
    );

    final reason = await controller.closed;
    _activeUndoWindows.remove(note.id);
    try {
      if (reason == SnackBarClosedReason.action) {
        await undo;
      } else {
        final confirmed = deletion.confirmDelete();
        await _localStore.saveDeletion(confirmed);
        await _finalizeDeletion(confirmed, force: true);
      }
    } catch (_) {
      unawaited(_resumeDeletionJournal());
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
      }
    }
  }

  Future<void> _undoDeletion(PendingNoteDeletion deletion) async {
    final undo = deletion.requestUndo();
    await _localStore.saveDeletion(undo);
    await _backend.undoNoteDeletion(deletion.noteId);
    await _localStore.removeDeletion(deletion.noteId);
  }

  Future<void> _resumeDeletionJournal() async {
    List<PendingNoteDeletion> deletions;
    try {
      deletions = await _localStore.loadDeletions();
    } catch (_) {
      return;
    }
    for (final deletion in deletions) {
      if (deletion.undoRequested) {
        try {
          await _backend.undoNoteDeletion(deletion.noteId);
          await _localStore.removeDeletion(deletion.noteId);
        } catch (_) {
          _scheduleJournalRetry();
        }
      } else if (deletion.deleteConfirmed) {
        unawaited(_finalizeDeletion(deletion, force: true));
      } else {
        _scheduleCleanup(deletion);
      }
    }
  }

  void _scheduleJournalRetry() {
    _cleanupTimers['journal']?.cancel();
    _cleanupTimers['journal'] = Timer(
      const Duration(seconds: 10),
      () => unawaited(_resumeDeletionJournal()),
    );
  }

  void _scheduleCleanup(PendingNoteDeletion deletion) {
    if (_activeUndoWindows.contains(deletion.noteId)) return;
    final due = DateTime.fromMillisecondsSinceEpoch(
      deletion.finalizeAfterMillis,
    );
    final delay = due.difference(DateTime.now());
    _cleanupTimers[deletion.noteId]?.cancel();
    _cleanupTimers[deletion.noteId] = Timer(
      delay.isNegative ? Duration.zero : delay,
      () => unawaited(_finalizeDeletion(deletion)),
    );
  }

  Future<void> _finalizeDeletion(
    PendingNoteDeletion deletion, {
    bool force = false,
  }) async {
    if (!_cleanupInFlight.add(deletion.noteId)) return;
    try {
      if (!force) {
        final local = await _localStore.loadDeletions();
        final matching = local.where((item) => item.noteId == deletion.noteId);
        if (matching.isNotEmpty && matching.first.undoRequested) {
          await _backend.undoNoteDeletion(deletion.noteId);
          await _localStore.removeDeletion(deletion.noteId);
          _cleanupTimers.remove(deletion.noteId)?.cancel();
          return;
        }
      }
      final result = await _backend.finalizeNoteDeletion(
        deletion.noteId,
        ignoreGracePeriod: force,
      );
      switch (result) {
        case NoteDeletionFinalization.deleted:
          await _localStore.remove(deletion.noteId).catchError((_) {});
          await _localStore.removeDeletion(deletion.noteId).catchError((_) {});
          _cleanupTimers.remove(deletion.noteId)?.cancel();
        case NoteDeletionFinalization.cancelled:
          await _localStore.removeDeletion(deletion.noteId).catchError((_) {});
          _cleanupTimers.remove(deletion.noteId)?.cancel();
        case NoteDeletionFinalization.notReady:
          _scheduleCleanup(deletion);
      }
    } catch (_) {
      _cleanupTimers[deletion.noteId]?.cancel();
      _cleanupTimers[deletion.noteId] = Timer(
        const Duration(seconds: 10),
        () => unawaited(_finalizeDeletion(deletion, force: force)),
      );
    } finally {
      _cleanupInFlight.remove(deletion.noteId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageBody(
          maxWidth: 720,

          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.xl),
              ScreenHeader(
                title: 'notes'.tr(),
                subtitle: _loading
                    ? null
                    : 'open_count'.tr(namedArgs: {'count': '$_openCount'}),

                actions: const [SignOutOnCompact()],
              ),
              const SizedBox(height: Spacing.lg),

              Row(
                children: [
                  Expanded(
                    child: SearchPill(
                      controller: _searchController,
                      hint: 'search_hint'.tr(),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  _buildSortMenu(),
                ],
              ),
              _buildFilters(),
              const SizedBox(height: Spacing.sm),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
      floatingActionButton: CreateFab(
        heroTag: 'notes-create-fab',
        label: 'add_note'.tr(),
        onPressed: _create,
      ),
    );
  }

  Widget _buildSortMenu() {
    return PopupMenuButton<NoteSort>(
      tooltip: 'sort'.tr(),
      initialValue: _sort,
      onSelected: (value) => setState(() => _sort = value),
      itemBuilder: (context) => [
        for (final (sort, labelKey, icon) in const [
          (NoteSort.newest, 'newest', Icons.arrow_downward_rounded),
          (NoteSort.oldest, 'oldest', Icons.arrow_upward_rounded),
          (NoteSort.alphabetical, 'alphabetical', Icons.sort_by_alpha_rounded),
        ])
          PopupMenuItem(
            value: sort,
            child: Row(
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: Spacing.md),
                Text(labelKey.tr()),
              ],
            ),
          ),
      ],
      child: CircleAction(
        icon: Icons.sort_rounded,
        tooltip: 'sort'.tr(),

        active: _sort != NoteSort.newest,
        onTap: null,
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.only(top: Spacing.md),
      child: Row(
        children: [
          for (final (filter, labelKey) in const [
            (NoteFilter.all, 'filter_all'),
            (NoteFilter.open, 'filter_open'),
            (NoteFilter.done, 'filter_done'),
          ])
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: ChoiceChip(
                label: Text(labelKey.tr()),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        action: TextButton(
          onPressed: () => _listen(showLoading: true),
          child: Text('retry'.tr()),
        ),
      );
    }

    final notes = _visible;
    if (notes.isEmpty) return _buildEmptyState();

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const SizedBox(height: Spacing.sm),
      itemBuilder: (context, index) {
        final note = notes[index];
        return _NoteRow(
          note: note,
          onToggle: () => _backend.setCompleted(note.id, !note.completed),
          onDelete: () => _delete(note),
          onPin: () => _backend.setPinned(note.id, !note.pinned),
          onOpen: () => _open(note),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    if (_searchController.text.isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'no_search_results'.tr(),
        action: TextButton(
          onPressed: _searchController.clear,
          child: Text('clear_search'.tr()),
        ),
      );
    }

    if (_filter != NoteFilter.all) {
      return EmptyState(
        icon: Icons.filter_alt_off_rounded,
        title: _filter == NoteFilter.done
            ? 'no_done_notes'.tr()
            : 'no_open_notes'.tr(),
        action: TextButton(
          onPressed: () => setState(() => _filter = NoteFilter.all),
          child: Text('filter_all'.tr()),
        ),
      );
    }

    return EmptyState(
      icon: Icons.edit_note_rounded,
      title: 'no_notes'.tr(),
      body: 'no_notes_body'.tr(),
    );
  }
}

class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.note,
    required this.onToggle,
    required this.onDelete,
    required this.onPin,
    required this.onOpen,
  });

  final NoteItem note;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onPin;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return ContentCard(
      onTap: onOpen,
      muted: note.completed,
      accent: note.pinned ? scheme.primary : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: note.completed,
                onChanged: (_) => onToggle(),

                semanticLabel: note.title,
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    decoration: note.completed
                        ? TextDecoration.lineThrough
                        : null,
                    color: note.completed ? scheme.onSurfaceVariant : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note.isEmpty ? 'note_empty'.tr() : note.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontStyle: note.isEmpty ? FontStyle.italic : null,
                  ),
                ),
                if (note.updatedAt case final updatedAt?) ...[
                  const SizedBox(height: Spacing.xs),
                  Text(
                    'edited_on'.tr(
                      namedArgs: {
                        'date': DateFormat.MMMd().add_jm().format(updatedAt),
                      },
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Spacing.xs),
          Column(
            children: [
              IconButton(
                tooltip: note.pinned ? 'unpin'.tr() : 'pin'.tr(),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  note.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  size: 18,
                  color: note.pinned ? scheme.primary : scheme.onSurfaceVariant,
                ),
                onPressed: onPin,
              ),
              IconButton(
                tooltip: 'delete'.tr(),
                visualDensity: VisualDensity.compact,

                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
