import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('organizer edit dialog lists the affected original slot labels', () {
    final source = File(
      'lib/appointments/edit/appointment_edit.dart',
    ).readAsStringSync();

    expect(
      source,
      matches(
        RegExp(
          r'on AppointmentVotedSlotRemovalBlocked catch \(error\)'
          r'[\s\S]*?error\.blockedSlotIds'
          r'[\s\S]*?originalSlots\[slotId\]'
          r'[\s\S]*?map\(_originalSlotLabel\)'
          r'[\s\S]*?appointment_voted_slots_blocked_body'
          r'[\s\S]*?namedArgs: \{\x27slots\x27: labels\}',
        ),
      ),
    );
    expect(source, contains('appointment_voted_slots_blocked_title'));
    expect(source, contains("child: Text('ok'.tr())"));
  });

  test('every release locale keeps the affected-slot placeholder', () {
    for (final locale in ['en', 'de', 'sq']) {
      final translations =
          json.decode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final title = translations['appointment_voted_slots_blocked_title'];
      final body = translations['appointment_voted_slots_blocked_body'];
      expect(
        title,
        isA<String>().having((value) => value.trim(), 'title', isNotEmpty),
      );
      expect(
        body,
        isA<String>().having((value) => value, 'body', contains('{slots}')),
      );
    }
  });
}
