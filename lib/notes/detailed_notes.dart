import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/layout/breakpoints.dart';
import 'package:echomeet/core/layout/page_body.dart';
import 'package:echomeet/core/widgets/feature_kit.dart';
import 'package:echomeet/notes/detailed_note_backend.dart';
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
  final _focus = FocusNode();
  final _scroll = ScrollController();

  late final TextEditingController _titleController = TextEditingController(
    text: widget.title,
  );

  QuillController? _controller;
  StreamSubscription<DocChange>? _changes;
  Timer? _debounce;

  _SaveState _state = _SaveState.clean;
  String? _loadError;
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
    _changes?.cancel();

    _controller?.dispose();
    _titleController.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final body = await _backend.loadNote(widget.noteId);
    if (!mounted) {
      body.controller.dispose();
      return;
    }

    setState(() {
      _controller = body.controller;
      _loadError = body.error;
    });

    _changes = body.controller.document.changes.listen((_) => _markDirty());
  }

  void _onTitleChanged() {
    if (_titleController.text.trim() == widget.title.trim()) return;
    _markDirty();
  }

  void _markDirty() {
    if (_loadError != null) return;
    if (_state != _SaveState.dirty) setState(() => _state = _SaveState.dirty);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1200), _save);
  }

  Future<void> _save() async {
    final controller = _controller;

    if (controller == null || _loadError != null) return;

    _debounce?.cancel();
    setState(() => _state = _SaveState.saving);

    final title = _titleController.text.trim();

    try {
      await Future.wait([
        _backend.saveNote(widget.noteId, controller),
        if (title.isNotEmpty && title != widget.title)
          _notes.renameNote(widget.noteId, title),
      ]);
      if (!mounted) return;
      setState(() => _state = _SaveState.saved);
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _SaveState.failed);
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

  Future<void> _flush() async {
    if (_state == _SaveState.dirty || _debounce?.isActive == true) {
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) => _flush(),
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
            (_, final error?) => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'note_load_failed'.tr(),

              body: error,
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
              focus: _focus,
              scroll: _scroll,
              state: _state,
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
    required this.focus,
    required this.scroll,
    required this.state,
  });

  final QuillController controller;
  final TextEditingController titleController;
  final FocusNode focus;
  final ScrollController scroll;
  final _SaveState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'note_title'.tr(),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: Spacing.xs),
              _SaveStatus(state: state),
              const SizedBox(height: Spacing.sm),
            ],
          ),
        ),

        Container(
          decoration: BoxDecoration(
            border: Border.symmetric(
              horizontal: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: QuillSimpleToolbar(
            controller: controller,
            config: const QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showFontFamily: false,
              showFontSize: false,
              showBackgroundColorButton: false,
              showSubscript: false,
              showSuperscript: false,
              showSearchButton: false,
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
