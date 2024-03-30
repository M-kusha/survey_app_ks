import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/notes/notes_logics.dart';
import 'package:flutter/material.dart';

class DialogUtils {
  static Future<void> displayAddNoteDialog(
      BuildContext context,
      TextEditingController textEditingController,
      TodoListBackend backend) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('add_note'.tr()),
          content: TextField(
            controller: textEditingController,
            decoration: InputDecoration(
              hintText: 'write_note'.tr(),
            ),
          ),
          actions: <Widget>[
            ElevatedButton(
              onPressed: () {
                if (textEditingController.text.isNotEmpty) {
                  backend.addNoteItem(textEditingController.text);
                  textEditingController.clear();
                  Navigator.of(context).pop();
                }
              },
              child: Text('add'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('cancel'.tr()),
            ),
          ],
        );
      },
    );
  }
}
