import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/widgets/app_text_field.dart';
import 'package:echomeet/notes/notes_logics.dart';
import 'package:flutter/material.dart';

class DialogUtils {
  static Future<({String id, String title})?> displayAddNoteDialog(
    BuildContext context,
    TodoListBackend backend,
  ) {
    return showDialog<({String id, String title})>(
      context: context,
      builder: (context) => _AddNoteDialog(backend: backend),
    );
  }
}

class _AddNoteDialog extends StatefulWidget {
  const _AddNoteDialog({required this.backend});

  final TodoListBackend backend;

  @override
  State<_AddNoteDialog> createState() => _AddNoteDialogState();
}

class _AddNoteDialogState extends State<_AddNoteDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    try {
      final title = _controller.text.trim();
      final id = await widget.backend.addNoteItem(title);
      if (!mounted) return;
      Navigator.of(context).pop((id: id, title: title));
    } catch (_) {
      if (!mounted) return;

      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('error_occurred'.tr())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('add_note'.tr()),
      content: Form(
        key: _formKey,
        child: AppTextField(
          label: 'note_title'.tr(),
          hint: 'write_note'.tr(),
          controller: _controller,
          textInputAction: TextInputAction.done,

          onSubmitted: (_) => _submit(),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'note_title_required'.tr()
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('add'.tr()),
        ),
      ],
    );
  }
}
