import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:survey_app_ks/utilities/colors.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  TodoListState createState() => TodoListState();
}

class TodoListState extends State<TodoList> {
  final TextEditingController _textFieldController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
  }

  String get userToken => _auth.currentUser!.uid;

  void _addNotesItem(String task) {
    FirebaseFirestore.instance.collection('notes').add({
      'title': task,
      'completed': false,
      'userToken': userToken,
    });
  }

  void _deleteNotesItem(DocumentReference docRef) {
    docRef.delete();
  }

  void _completeNotesItem(DocumentReference docRef, bool completed) {
    docRef.update({'completed': !completed});
  }

  Widget _buildNotesList() {
    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('notes')
          .where('userToken', isEqualTo: userToken)
          .snapshots(),
      builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var doc = snapshot.data!.docs[index];
            bool completed = doc['completed'] ?? false;
            return _buildNotesItem(doc['title'], completed, doc.reference);
          },
        );
      },
    );
  }

  Widget _buildNotesItem(
      String title, bool completed, DocumentReference docRef) {
    return Card(
      elevation: 1,
      shadowColor: ThemeBasedAppColors.getColor(context, 'buttonColor'),
      child: ListTile(
        title: Text(
          title,
          style: TextStyle(
            decoration: completed ? TextDecoration.lineThrough : null,
            color: completed ? Colors.red : null,
          ),
        ),
        trailing: IconButton(
          icon: Icon(
            completed ? Icons.undo : Icons.done,
            color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
          ),
          onPressed: () => _completeNotesItem(docRef, completed),
        ),
        onTap: () => _completeNotesItem(docRef, completed),
        onLongPress: () => _deleteNotesItem(docRef),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: _buildNotesList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ThemeBasedAppColors.getColor(
            context, 'buttonColor'), // Saturated color for light theme
        onPressed: () => _displayDialog(context),
        tooltip: 'Add Item',
        child: Icon(
          Icons.add,
          color: ThemeBasedAppColors.getColor(context, 'textColor'),
        ),
      ),
    );
  }

  _displayDialog(BuildContext context) async {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add a new note'),
          content: TextField(
            controller: _textFieldController,
            decoration: const InputDecoration(hintText: 'Enter note here'),
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeBasedAppColors.getColor(
                    context, 'textColor'), // Saturated color for light theme
              ),
              onPressed: () {
                _addNotesItem(_textFieldController.text);
                _textFieldController.clear();
                Navigator.of(context).pop();
              },
              child: Text(
                'Add',
                style: TextStyle(
                  color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeBasedAppColors.getColor(
                    context, 'textColor'), // Saturated color for light theme
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: ThemeBasedAppColors.getColor(context, 'buttonColor'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
