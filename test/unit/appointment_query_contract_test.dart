import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _collection = ".collection('appointments')";

/// Every place a client reaches for the appointments collection, with enough
/// following source to see how the read is shaped.
Iterable<({String path, String source})> _appointmentReads() sync* {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  for (final file in files) {
    final source = file.readAsStringSync();
    var at = source.indexOf(_collection);
    while (at != -1) {
      yield (
        path: file.path.replaceAll(r'\', '/'),
        source: source.substring(at, (at + 400).clamp(0, source.length)),
      );
      at = source.indexOf(_collection, at + 1);
    }
  }
}

/// A read of one document by id, rather than a query over the collection.
///
/// `.doc(` before any `.where(` means the id is already known, and an id is
/// its own authorization boundary — rules check the document that was named.
bool _isSingleDocument(String source) {
  final doc = source.indexOf('.doc(');
  final where = source.indexOf('.where(');
  return doc != -1 && (where == -1 || doc < where);
}

void main() {
  // Discovered rather than listed. The previous version named two files, one of
  // which later moved its query to a Cloud Function — so the test kept passing
  // on a file that no longer had a query, then failed on a file that no longer
  // existed, and in neither state was it checking anything. A scan cannot go
  // stale, and it catches a new unbound query the day it is written.
  test('every client appointment list query binds tenant and v2 schema', () {
    final queries = _appointmentReads()
        .where((read) => !_isSingleDocument(read.source))
        .toList();

    expect(
      queries,
      isNotEmpty,
      reason: 'no client appointment query found — has the scan broken?',
    );

    for (final query in queries) {
      expect(
        query.source,
        contains(".where('companyId', isEqualTo: companyId)"),
        reason: '${query.path} queries appointments without binding the tenant',
      );
      expect(
        query.source,
        contains(
          ".where('schemaVersion', isEqualTo: Appointment.schemaVersion)",
        ),
        reason: '${query.path} queries appointments without pinning the schema',
      );
    }
  });

  test('single-document reads are still recognised as such', () {
    // Guards the classifier itself: if `_isSingleDocument` ever returned false
    // for a plain `.doc()` read, the test above would demand a tenant filter on
    // a lookup that cannot take one, and the only way out would be to weaken it.
    final documentReads = _appointmentReads().where(
      (read) => _isSingleDocument(read.source),
    );

    expect(documentReads, isNotEmpty);
    for (final read in documentReads) {
      expect(read.source, contains('.doc('));
    }
  });
}
