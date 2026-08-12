import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/notes/detailed_note_backend.dart';
import 'package:echomeet/notes/note_draft_store.dart';
import 'package:echomeet/notes/notes_logics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class DetailedNotePage extends StatefulWidget {
  const DetailedNotePage({
    super.key,
    required this.noteId,
    required this.title,
    this.pinned = false,
  });

  final String noteId;
  final String title;
  final bool pinned;

  @override
  State<DetailedNotePage> createState() => _DetailedNotePageState();
}

enum _SaveState { clean, dirty, saving, saved, failed }

class _DetailedNotePageState extends State<DetailedNotePage> {
  final _backend = NotesBackend();
  final _notes = TodoListBackend();
  late final _drafts = NoteDraftStore();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  late final TextEditingController _titleController = TextEditingController(
    text: widget.title,
  );

  QuillController? _controller;
  StreamSubscription<DocChange>? _changes;
  Timer? _debounce;
  Future<bool>? _saveInFlight;
  Future<void> _draftQueue = Future<void>.value();

  _SaveState _state = _SaveState.clean;
  String? _loadError;
  var _revision = 0;
  var _savedRevision = 0;
  var _allowPop = false;
  var _closing = false;
  var _hydrating = false;
  var _titleMissing = false;
  var _serverRevision = 0;
  DateTime? _serverUpdatedAt;
  NoteDraft? _conflictingDraft;
  var _revisionConflict = false;
  int? _conflictCloudRevision;
  DateTime? _conflictCloudUpdatedAt;
  late bool _pinned = widget.pinned;

  @override
  void initState() {
    super.initState();
    _load();
    _titleController.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_revision != _savedRevision) _queueDraftSave();
    _changes?.cancel();

    _controller?.dispose();
    _titleController.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait<Object?>([
      _backend.loadNote(widget.noteId),
      _loadDraft(),
    ]);
    final body = results[0]! as NoteBody;
    var draft = results[1] as NoteDraft?;
    if (!mounted) {
      body.controller.dispose();
      return;
    }

    await _changes?.cancel();
    final previousController = _controller;

    var nextController = body.controller;
    var restoredDraft = false;
    _hydrating = true;
    final safeToRestore =
        body.error == null &&
        draft?.isSafeToAutoRestore(
              cloudRevision: body.revision,
              cloudUpdatedAtMillis: body.updatedAt?.millisecondsSinceEpoch,
            ) ==
            true;
    if (safeToRestore) {
      try {
        nextController = QuillController(
          document: Document.fromJson(draft!.content),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _titleController.text = draft.title;
        restoredDraft = true;
      } catch (_) {
        draft = null;
        unawaited(_drafts.remove(widget.noteId).catchError((_) {}));
      }
    }
    if (!restoredDraft) {
      _titleController.text = body.title?.trim().isNotEmpty == true
          ? body.title!
          : widget.title;
    }

    setState(() {
      _controller = nextController;
      _serverRevision = body.revision;
      _serverUpdatedAt = body.updatedAt;
      _conflictingDraft = !restoredDraft ? draft : null;
      _revisionConflict = false;
      _conflictCloudRevision = null;
      _conflictCloudUpdatedAt = null;
      _loadError = body.error;
      _revision = restoredDraft ? 1 : 0;
      _savedRevision = 0;
      _state = restoredDraft ? _SaveState.dirty : _SaveState.clean;
    });
    _hydrating = false;

    if (!identical(nextController, body.controller)) body.controller.dispose();
    if (!identical(previousController, nextController)) {
      previousController?.dispose();
    }

    _changes = nextController.document.changes.listen((_) => _markDirty());
    if (restoredDraft) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 1200), _save);
    }
  }

  Future<NoteDraft?> _loadDraft() async {
    try {
      return await _drafts.load(widget.noteId);
    } catch (_) {
      return null;
    }
  }

  void _onTitleChanged() {
    if (_hydrating) return;
    if (_titleController.text.trim().isNotEmpty && _titleMissing) {
      setState(() => _titleMissing = false);
    }
    _markDirty();
  }

  void _markDirty() {
    if (_hydrating || _loadError != null) return;
    _revision++;
    if (_state != _SaveState.dirty) setState(() => _state = _SaveState.dirty);

    _queueDraftSave();

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _save);
  }

  void _queueDraftSave() {
    final controller = _controller;
    if (controller == null) return;

    final draft = NoteDraft(
      title: _titleController.text,
      content: controller.document.toDelta().toJson(),
      baseRevision: _serverRevision,
      baseUpdatedAtMillis: _serverUpdatedAt?.millisecondsSinceEpoch,
      savedAtMillis: DateTime.now().millisecondsSinceEpoch,
    );
    final previous = _draftQueue;
    _draftQueue = () async {
      try {
        await previous;
      } catch (_) {}
      await _drafts.save(widget.noteId, draft);
    }();
    unawaited(_draftQueue.catchError((_) {}));
  }

  void _queueDraftRemoval(int savedRevision) {
    final previous = _draftQueue;
    _draftQueue = () async {
      try {
        await previous;
      } catch (_) {}
      if (_revision == savedRevision && _savedRevision == savedRevision) {
        await _drafts.remove(widget.noteId);
      }
    }();
    unawaited(_draftQueue.catchError((_) {}));
  }

  Future<bool> _save() async {
    final controller = _controller;

    if (controller == null || _loadError != null || _revisionConflict) {
      return false;
    }

    _debounce?.cancel();

    while (true) {
      final pending = _saveInFlight;
      if (pending == null) break;
      await pending;
      if (identical(_saveInFlight, pending)) _saveInFlight = null;
    }

    if (_revision == _savedRevision && _state != _SaveState.failed) {
      return true;
    }

    final operation = _performSave(controller);
    _saveInFlight = operation;
    try {
      return await operation;
    } finally {
      if (identical(_saveInFlight, operation)) _saveInFlight = null;
    }
  }

  Future<bool> _performSave(QuillController controller) async {
    final revision = _revision;
    if (mounted) setState(() => _state = _SaveState.saving);

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      if (mounted) {
        setState(() {
          _titleMissing = true;
          _state = _SaveState.failed;
        });
      }
      return false;
    }

    try {
      final result = await _backend.saveNote(
        widget.noteId,
        title: title,
        content: controller.document.toDelta().toJson(),
        plainText: controller.document.toPlainText(),
        expectedRevision: _serverRevision,
        expectedUpdatedAt: _serverUpdatedAt,
      );
      _serverRevision = result.revision;
      _serverUpdatedAt = result.updatedAt;
      _savedRevision = revision;
      if (_revision == revision) {
        _queueDraftRemoval(revision);
      } else {
        _queueDraftSave();
      }
      if (mounted) {
        setState(
          () => _state = _revision == revision
              ? _SaveState.saved
              : _SaveState.dirty,
        );
      }
      return true;
    } on NoteRevisionConflictException catch (error) {
      _conflictCloudRevision = error.cloudRevision;
      _conflictCloudUpdatedAt = error.cloudUpdatedAt;
      _revisionConflict = true;
      _queueDraftSave();
      if (mounted) setState(() => _state = _SaveState.failed);
      return false;
    } catch (_) {
      if (mounted) setState(() => _state = _SaveState.failed);
      return false;
    }
  }

  Future<void> _togglePin() async {
    final next = !_pinned;
    setState(() => _pinned = next);
    try {
      await _notes.setPinned(widget.noteId, next);
    } catch (_) {
      if (mounted) setState(() => _pinned = !next);
    }
  }

  Future<void> _useLocalCopy() async {
    _debounce?.cancel();

    if (_revisionConflict) {
      setState(() {
        _serverRevision = _conflictCloudRevision ?? _serverRevision;
        _serverUpdatedAt = _conflictCloudUpdatedAt;
        _revisionConflict = false;
        _conflictCloudRevision = null;
        _conflictCloudUpdatedAt = null;
        _state = _SaveState.dirty;
      });
      _queueDraftSave();
      unawaited(_save());
      return;
    }

    final draft = _conflictingDraft;
    if (draft == null) return;

    late final QuillController recovered;
    try {
      recovered = QuillController(
        document: Document.fromJson(draft.content),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      await _drafts.remove(widget.noteId).catchError((_) {});
      if (mounted) setState(() => _conflictingDraft = null);
      return;
    }

    await _changes?.cancel();
    final previous = _controller;
    _hydrating = true;
    _titleController.text = draft.title;
    _hydrating = false;
    setState(() {
      _controller = recovered;
      _conflictingDraft = null;
      _revision++;
      _state = _SaveState.dirty;
    });
    previous?.dispose();
    _changes = recovered.document.changes.listen((_) => _markDirty());
    _queueDraftSave();
    unawaited(_save());
  }

  Future<void> _keepCloudCopy() async {
    _debounce?.cancel();
    _revisionConflict = false;
    _conflictingDraft = null;
    _conflictCloudRevision = null;
    _conflictCloudUpdatedAt = null;
    _savedRevision = _revision;
    try {
      await _draftQueue;
    } catch (_) {}
    await _drafts.remove(widget.noteId).catchError((_) {});
    if (mounted) await _load();
  }

  Future<bool> _flush() async {
    if (_revisionConflict) {
      try {
        await _draftQueue;
      } catch (_) {}
      return true;
    }
    if (_revision != _savedRevision ||
        _debounce?.isActive == true ||
        _saveInFlight != null) {
      return _save();
    }
    return _state != _SaveState.failed;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _closing) return;
        _closing = true;

        final saved = await _flush();
        if (!context.mounted) return;
        if (!saved) {
          _closing = false;
          return;
        }

        setState(() => _allowPop = true);
        Navigator.of(context).pop(result);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('note'.tr()),
          actions: [
            IconButton(
              tooltip: _pinned ? 'unpin'.tr() : 'pin'.tr(),
              onPressed: _togglePin,
              icon: Icon(
                _pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              ),
            ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
        body: SafeArea(
          child: switch ((controller, _loadError)) {
            (_, String()) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'note_load_failed'.tr(),
              body: _conflictingDraft == null
                  ? null
                  : 'note_local_preserved_offline'.tr(),
              action: TextButton(
                onPressed: () {
                  setState(() => _loadError = null);
                  _load();
                },
                child: Text('retry'.tr()),
              ),
            ),
            (null, _) => const Center(child: CircularProgressIndicator()),
            (final controller?, _) => _Editor(
              controller: controller,
              titleController: _titleController,
              titleMissing: _titleMissing,
              focus: _focus,
              scroll: _scroll,
              state: _state,
              conflict: _conflictingDraft != null || _revisionConflict,
              onUseLocal: _useLocalCopy,
              onKeepCloud: _keepCloudCopy,
            ),
          },
        ),
      ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.controller,
    required this.titleController,
    required this.titleMissing,
    required this.focus,
    required this.scroll,
    required this.state,
    required this.conflict,
    required this.onUseLocal,
    required this.onKeepCloud,
  });

  final QuillController controller;
  final TextEditingController titleController;
  final bool titleMissing;
  final FocusNode focus;
  final ScrollController scroll;
  final _SaveState state;
  final bool conflict;
  final VoidCallback onUseLocal;
  final VoidCallback onKeepCloud;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    controller.readOnly = conflict;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageBody(
          maxWidth: 760,
          scrollable: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Spacing.md),

              TextField(
                controller: titleController,
                readOnly: conflict,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'note_title'.tr(),
                  errorText: titleMissing ? 'note_title_required'.tr() : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              _SaveStatus(state: state),
              const SizedBox(height: Spacing.sm),
              if (conflict) ...[
                _NoteConflictBanner(
                  onUseLocal: onUseLocal,
                  onKeepCloud: onKeepCloud,
                ),
                const SizedBox(height: Spacing.sm),
              ],
            ],
          ),
        ),

        if (!conflict)
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: QuillSimpleToolbar(
              controller: controller,
              config: QuillSimpleToolbarConfig(
                multiRowsDisplay: false,
                showFontFamily: false,
                showFontSize: false,
                showBackgroundColorButton: false,
                showSubscript: false,
                showSuperscript: false,
                showSearchButton: false,

                toolbarSize: context.isCompact ? 34 : 42,
                buttonOptions: QuillSimpleToolbarButtonOptions(
                  base: QuillToolbarBaseButtonOptions(
                    iconTheme: QuillIconTheme(
                      iconButtonSelectedData: IconButtonData(
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary.withValues(
                            alpha: 0.14,
                          ),
                          foregroundColor: theme.colorScheme.primary,
                          minimumSize: const Size.square(30),
                        ),
                      ),
                      iconButtonUnselectedData: IconButtonData(
                        style: IconButton.styleFrom(
                          foregroundColor: theme.colorScheme.onSurfaceVariant,
                          minimumSize: const Size.square(30),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: PageBody(
            maxWidth: 760,
            scrollable: false,
            child: QuillEditor(
              controller: controller,
              focusNode: focus,
              scrollController: scroll,
              config: QuillEditorConfig(
                placeholder: 'start_writting'.tr(),
                padding: const EdgeInsets.symmetric(vertical: Spacing.md),
                expands: true,
                autoFocus: false,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoteConflictBanner extends StatelessWidget {
  const _NoteConflictBanner({
    required this.onUseLocal,
    required this.onKeepCloud,
  });

  final VoidCallback onUseLocal;
  final VoidCallback onKeepCloud;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'note_conflict_title'.tr(),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'note_conflict_body'.tr(),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            children: [
              FilledButton.tonal(
                onPressed: onUseLocal,
                child: Text('use_local_note'.tr()),
              ),
              TextButton(
                onPressed: onKeepCloud,
                child: Text('keep_cloud_note'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SaveStatus extends StatelessWidget {
  const _SaveStatus({required this.state});

  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (icon, labelKey, color) = switch (state) {
      _SaveState.clean => (Icons.cloud_done_outlined, 'saved', null),
      _SaveState.dirty => (Icons.edit_outlined, 'unsaved_changes', null),
      _SaveState.saving => (Icons.sync_rounded, 'saving', null),
      _SaveState.saved => (Icons.cloud_done_rounded, 'saved', null),
      _SaveState.failed => (
        Icons.cloud_off_rounded,
        'save_failed',
        scheme.error,
      ),
    };

    return Row(
      children: [
        Icon(icon, size: 14, color: color ?? scheme.onSurfaceVariant),
        const SizedBox(width: Spacing.xs),
        Text(
          labelKey.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: color ?? scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
