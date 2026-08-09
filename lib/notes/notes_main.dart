import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/core/widgets/sign_out_button.dart';
import 'package:echomeet/notes/add_item_widget.dart';
import 'package:echomeet/notes/detailed_notes.dart';
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
  final _searchController = TextEditingController();

  StreamSubscription<QuerySnapshot>? _subscription;

  List<NoteItem> _notes = [];
  NoteFilter _filter = NoteFilter.all;
  NoteSort _sort = NoteSort.newest;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _subscription = _backend.userNotesCollection.snapshots().listen(
      (snapshot) {
        if (!mounted) return;
        setState(() {
          _notes = snapshot.docs.map(_toNote).toList();
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
    await _backend.deleteNote(note.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('note_deleted'.tr()),

          showCloseIcon: true,
          action: SnackBarAction(
            label: 'undo'.tr(),
            onPressed: () => _backend.restoreNote(
              title: note.title,
              completed: note.completed,
            ),
          ),
        ),
      );
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

    if (_error case final error?) {
      return EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'error_occurred'.tr(),
        body: error,
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
