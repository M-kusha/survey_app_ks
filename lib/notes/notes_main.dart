import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/main_screen/appointment_search_field.dart';
import 'package:echomeet/notes/add_item_widget.dart';
import 'package:echomeet/notes/detailed_notes.dart';
import 'package:echomeet/notes/filter_widget.dart';
import 'package:echomeet/notes/pagination_widget.dart';
import 'package:echomeet/notes/search_widget.dart';
import 'package:echomeet/notes/sorting_widget.dart';
import 'package:echomeet/utilities/tablet_size.dart';
import 'package:echomeet/utilities/text_style.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/settings/font_size_provider.dart';
import 'package:echomeet/notes/notes_logics.dart';

class TodoList extends StatefulWidget {
  const TodoList({super.key});

  @override
  TodoListState createState() => TodoListState();
}

class TodoListState extends State<TodoList> {
  final TodoListBackend _backend = TodoListBackend();
  List<DocumentSnapshot> _notes = [];
  List<DocumentSnapshot> _filteredNotes = [];
  bool isSearching = false;
  TextEditingController searchController = TextEditingController();
  TextEditingController textEditingController = TextEditingController();
  String searchQuery = '';
  int selectedSortOption = 0;
  final int itemsPerPage = 9;
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    searchController.addListener(_filterNotes);
  }

  void _loadNotes() {
    _backend.userNotesCollection.snapshots().listen((snapshot) {
      setState(() {
        _notes = snapshot.docs;
        _applyFilters();
      });
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredNotes = FilterLogic.applyFilters(_notes, selectedSortOption);
    });
    _filterNotes();
  }

  _displayDialog(BuildContext context) async {
    return DialogUtils.displayAddNoteDialog(
        context, textEditingController, _backend);
  }

  void _filterNotes() {
    final query = searchController.text.toLowerCase();
    setState(() {
      _filteredNotes = _notes.where((doc) {
        final title = doc['title'].toString().toLowerCase();
        return title.contains(query);
      }).toList();
    });
  }

  void _onSearchTextChanged(String text) async {
    setState(() {
      searchQuery = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontSize = Provider.of<FontSizeProvider>(context).fontSize;
    final timeFontSize = getTimeFontSize(context, fontSize);

    return Scaffold(
      appBar: AppBar(
        leading: sorting(context),
        title: isSearching
            ? ActionField(
                isSearching: isSearching,
                searchController: searchController,
                onSearchTextChanged: _onSearchTextChanged,
              )
            : Text('notes'.tr(),
                style: theme.textTheme.titleLarge!
                    .copyWith(fontSize: timeFontSize)),
        centerTitle: true,
        actions: [
          _buildSearchBar(theme.primaryColor),
        ],
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: _filteredNotes.isEmpty
          ? Center(
              child: Text(
                isSearching ? 'no_items'.tr() : 'no_notes'.tr(),
                style: theme.textTheme.titleLarge,
              ),
            )
          : _buildNotesList(theme),
      floatingActionButton: FloatingActionButton(
        backgroundColor: getButtonColor(context),
        onPressed: () => _displayDialog(context),
        tooltip: 'add_note'.tr(),
        child: Icon(Icons.add, color: theme.scaffoldBackgroundColor),
      ),
    );
  }

  Widget _buildNotesList(ThemeData theme) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: getNotesForCurrentPage().length,
            itemBuilder: (context, index) {
              var doc = _filteredNotes[index];
              bool completed = doc['completed'] ?? false;
              return _buildNotesItem(
                  doc['title'], completed, doc.reference, theme);
            },
          ),
        ),
        if (_filteredNotes.length > itemsPerPage) pagination(),
      ],
    );
  }

  Widget _buildNotesItem(
      String title, bool completed, DocumentReference docRef, ThemeData theme) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => DetailedNotePage(
          noteId: docRef.id,
          title: title,
        ),
      )),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Card(
          elevation: 1,
          shadowColor: getButtonColor(context),
          child: ListTile(
            leading: Checkbox(
              activeColor: getButtonColor(context),
              value: completed,
              onChanged: (bool? value) {
                _backend.completeNotesItem(docRef, completed);
              },
            ),
            title: Padding(
              padding: const EdgeInsets.only(right: 20.0),
              child: Text(
                title,
                style: theme.textTheme.titleMedium!.copyWith(
                  decoration: completed ? TextDecoration.lineThrough : null,
                  color: completed ? Colors.grey : null,
                ),
              ),
            ),
            trailing: Wrap(
              spacing: 12,
              children: <Widget>[
                IconButton(
                  icon: const Icon(Icons.remove, color: Colors.red),
                  onPressed: () => _backend.deleteNotesItem(docRef),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget sorting(BuildContext context) {
    return SortingWidget(
      selectedSortOption: selectedSortOption,
      onSortOptionSelected: (int result) {
        setState(() {
          selectedSortOption = result;
          _applyFilters();
        });
      },
    );
  }

  List<DocumentSnapshot> getNotesForCurrentPage() {
    final int startIndex = (currentPage - 1) * itemsPerPage;
    final int endIndex = startIndex + itemsPerPage;
    if (endIndex > _filteredNotes.length) {
      return _filteredNotes.sublist(startIndex);
    } else {
      return _filteredNotes.sublist(startIndex, endIndex);
    }
  }

  Widget _buildSearchBar(Color buttonColor) {
    return SearchWidget(
      isSearching: isSearching,
      searchController: searchController,
      onSearchTextChanged: (String searchText) {
        setState(() {
          isSearching = !isSearching;
          if (!isSearching) {
            searchController.clear();
            _filterNotes();
          }
        });
      },
    );
  }

  Widget pagination() {
    return PaginationWidget(
      currentPage: currentPage,
      totalPages: (_filteredNotes.length / itemsPerPage).ceil(),
      onPreviousPage: () {
        setState(() {
          currentPage--;
        });
      },
      onNextPage: () {
        setState(() {
          currentPage++;
        });
      },
    );
  }
}
