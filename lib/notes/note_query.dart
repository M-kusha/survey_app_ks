library;

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.completed,
    this.preview = '',
    this.pinned = false,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final bool completed;

  final String preview;

  final bool pinned;

  final DateTime? createdAt;

  final DateTime? updatedAt;

  bool get isEmpty => preview.trim().isEmpty;
}

enum NoteFilter { all, open, done }

enum NoteSort { newest, oldest, alphabetical }

List<NoteItem> queryNotes(
  List<NoteItem> notes, {
  String search = '',
  NoteFilter filter = NoteFilter.all,
  NoteSort sort = NoteSort.newest,
}) {
  final needle = search.trim().toLowerCase();

  final result = notes.where((note) {
    final matchesSearch =
        needle.isEmpty || note.title.toLowerCase().contains(needle);
    final matchesFilter = switch (filter) {
      NoteFilter.all => true,
      NoteFilter.open => !note.completed,
      NoteFilter.done => note.completed,
    };
    return matchesSearch && matchesFilter;
  }).toList();

  result.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;

    return switch (sort) {
      NoteSort.newest => _byDate(b, a),
      NoteSort.oldest => _byDate(a, b),
      NoteSort.alphabetical => a.title.toLowerCase().compareTo(
        b.title.toLowerCase(),
      ),
    };
  });

  return result;
}

int _byDate(NoteItem a, NoteItem b) {
  final left = a.createdAt;
  final right = b.createdAt;

  if (left == null && right == null) return 0;
  if (left == null) return 1;
  if (right == null) return -1;
  return left.compareTo(right);
}
