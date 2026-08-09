import 'package:echomeet/notes/note_query.dart';
import 'package:flutter_test/flutter_test.dart';

NoteItem note(
  String title, {
  bool completed = false,
  DateTime? at,
  String id = 'id',
  bool pinned = false,
}) => NoteItem(
  id: id,
  title: title,
  completed: completed,
  createdAt: at,
  pinned: pinned,
);

List<String> titles(List<NoteItem> notes) =>
    notes.map((note) => note.title).toList();

void main() {
  final monday = DateTime(2025, 1, 6);
  final tuesday = DateTime(2025, 1, 7);
  final wednesday = DateTime(2025, 1, 8);

  group('search', () {
    test('matches part of a title, ignoring case', () {
      final notes = [note('Buy milk'), note('Call the bank')];
      expect(titles(queryNotes(notes, search: 'MILK')), ['Buy milk']);
    });

    test('a blank search returns everything', () {
      final notes = [note('one'), note('two')];
      expect(queryNotes(notes, search: '   '), hasLength(2));
    });
  });

  group('filter', () {
    final notes = [
      note('done one', completed: true),
      note('open one'),
      note('done two', completed: true),
    ];

    test('open shows only the unfinished', () {
      expect(titles(queryNotes(notes, filter: NoteFilter.open)), ['open one']);
    });

    test('done shows only the finished', () {
      expect(queryNotes(notes, filter: NoteFilter.done), hasLength(2));
    });
  });

  test('filter and sort apply together', () {
    // The old code put both behind one integer, so choosing "oldest first"
    // silently turned off "only show what is unfinished".
    final notes = [
      note('b open', at: wednesday),
      note('done', completed: true, at: monday),
      note('a open', at: tuesday),
    ];

    final result = queryNotes(
      notes,
      filter: NoteFilter.open,
      sort: NoteSort.oldest,
    );

    expect(titles(result), ['a open', 'b open']);
  });

  test('search, filter and sort all apply at once', () {
    final notes = [
      note('report draft', at: monday),
      note('report final', completed: true, at: tuesday),
      note('groceries', at: wednesday),
      note('report notes', at: wednesday),
    ];

    final result = queryNotes(
      notes,
      search: 'report',
      filter: NoteFilter.open,
      sort: NoteSort.newest,
    );

    expect(titles(result), ['report notes', 'report draft']);
  });

  group('sort', () {
    test('newest first', () {
      final notes = [note('old', at: monday), note('new', at: wednesday)];
      expect(titles(queryNotes(notes, sort: NoteSort.newest)), ['new', 'old']);
    });

    test('alphabetical ignores case', () {
      final notes = [note('banana'), note('Apple'), note('cherry')];
      expect(titles(queryNotes(notes, sort: NoteSort.alphabetical)), [
        'Apple',
        'banana',
        'cherry',
      ]);
    });

    test('a note still awaiting its server timestamp sorts as newest', () {
      // Firestore reports a pending write before the server stamps it, so the
      // note the user just typed has a null date. The old comparator called
      // compareTo on that null and threw.
      final notes = [note('saved', at: wednesday), note('just typed')];

      expect(titles(queryNotes(notes, sort: NoteSort.newest)), [
        'just typed',
        'saved',
      ]);
    });

    test('two unstamped notes do not throw', () {
      final notes = [note('a'), note('b')];
      expect(() => queryNotes(notes, sort: NoteSort.newest), returnsNormally);
    });
  });

  test('the source list is never reordered', () {
    // `applyFilters` sorted the list it was handed, so displaying the notes
    // rearranged the state the screen was holding.
    final notes = [note('b', at: monday), note('a', at: wednesday)];
    final original = titles(notes);

    queryNotes(notes, sort: NoteSort.alphabetical);

    expect(titles(notes), original);
  });

  group('pinned', () {
    test('pinned notes lead, whatever the sort', () {
      final notes = [
        note('a', at: wednesday),
        note('b', at: monday, pinned: true),
        note('c', at: tuesday),
      ];

      // Newest-first would put 'a' on top; the pin outranks it. A pin the sort
      // order can override is not a pin.
      expect(titles(queryNotes(notes, sort: NoteSort.newest)), ['b', 'a', 'c']);
      expect(titles(queryNotes(notes, sort: NoteSort.alphabetical)), [
        'b',
        'a',
        'c',
      ]);
    });

    test('the chosen sort still orders within each group', () {
      final notes = [
        note('a', at: monday, pinned: true),
        note('b', at: wednesday, pinned: true),
        note('c', at: monday),
        note('d', at: wednesday),
      ];

      expect(titles(queryNotes(notes, sort: NoteSort.newest)), [
        'b',
        'a',
        'd',
        'c',
      ]);
    });

    test('a pinned note is still hidden by a filter that excludes it', () {
      // Pinning is about order, not visibility. A pinned done note must not
      // reappear while the list is filtered to open ones.
      final notes = [note('a', completed: true, pinned: true), note('b')];
      expect(titles(queryNotes(notes, filter: NoteFilter.open)), ['b']);
    });
  });
}
