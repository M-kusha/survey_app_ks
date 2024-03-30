import 'package:cloud_firestore/cloud_firestore.dart';

class FilterLogic {
  static List<DocumentSnapshot> applyFilters(
      List<DocumentSnapshot> notes, int selectedSortOption) {
    List<DocumentSnapshot> filteredNotes = notes;

    switch (selectedSortOption) {
      case 0:
        filteredNotes.sort((a, b) => b['timestamp'].compareTo(a['timestamp']));
        break;
      case 1:
        filteredNotes.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        break;
      case 2:
        filteredNotes =
            filteredNotes.where((note) => note['completed'] == true).toList();
        break;
      case 3:
        filteredNotes =
            filteredNotes.where((note) => note['completed'] == false).toList();
        break;
    }

    return filteredNotes;
  }
}
