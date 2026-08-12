import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _collection = ".collection('appointments')";

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

bool _isSingleDocument(String source) {
  final doc = source.indexOf('.doc(');
  final where = source.indexOf('.where(');
  return doc != -1 && (where == -1 || doc < where);
}

void main() {
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
    final documentReads = _appointmentReads().where(
      (read) => _isSingleDocument(read.source),
    );

    expect(documentReads, isNotEmpty);
    for (final read in documentReads) {
      expect(read.source, contains('.doc('));
    }
  });
}
