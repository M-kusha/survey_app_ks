import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/notes/detailed_note_backend.dart';
import 'package:echomeet/utilities/reusable_widgets.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class DetailedNotePage extends StatefulWidget {
  final String noteId;
  final String title;

  const DetailedNotePage(
      {super.key, required this.noteId, required this.title});

  @override
  DetailedNotePageState createState() => DetailedNotePageState();
}

class DetailedNotePageState extends State<DetailedNotePage> {
  late QuillController _controller = QuillController.basic();
  final _notesBackend = NotesBackend();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  void _initializeController() async {
    final loadedController =
        await _notesBackend.loadNoteController(widget.noteId);
    if (mounted) {
      setState(() {
        _controller = loadedController;
      });
    }
  }

  void _onSavePressed() async {
    await _notesBackend.saveNote(widget.noteId, _controller);
    if (!mounted) return;

    UIUtils.showSnackBar(context, 'note_saved');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${'edit_note'.tr()} ${widget.title}',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _onSavePressed,
          ),
        ],
      ),
      body: Column(
        children: [
          Card(
            elevation: 5,
            shadowColor: getButtonColor(context),
            child: QuillToolbar.simple(
              configurations: QuillSimpleToolbarConfigurations(
                controller: _controller,
                sharedConfigurations: const QuillSharedConfigurations(),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
                elevation: 5,
                shadowColor: getButtonColor(context),
                child: QuillEditor.basic(
                  configurations: QuillEditorConfigurations(
                    placeholder: 'start_writting'.tr(),
                    padding: const EdgeInsets.all(8),
                    controller: _controller,
                    scrollable: true,
                    sharedConfigurations: const QuillSharedConfigurations(),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
