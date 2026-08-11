import 'dart:convert';

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/calendar/appointment_ics.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment _appointment({
  String title = 'Quarterly review',
  String description = 'Agenda attached.',
  String zoneId = 'Europe/Berlin',
  int revision = 1,
  DateTime? startAt,
  DateTime? endAt,
  bool confirmed = true,
}) {
  final start = startAt ?? DateTime.utc(2026, 7, 15, 7);
  final slot = TimeSlot(
    slotId: 'slot-a',
    start: start,
    end: endAt ?? start.add(const Duration(hours: 1)),
  );
  return Appointment(
    companyId: 'acme',
    createdBy: 'alice',
    appointmentId: 'appt-1',
    title: title,
    description: description,
    zoneId: zoneId,
    availableTimeSlots: [slot],
    expirationDate: start.subtract(const Duration(hours: 2)),
    creationDate: start.subtract(const Duration(days: 1)),
    revision: revision,
    confirmedSlotId: confirmed ? 'slot-a' : null,
  );
}

/// Unfolds per RFC 5545: a CRLF followed by a single space is not a break.
List<String> _contentLines(String ics) => ics
    .replaceAll('\r\n ', '')
    .split('\r\n')
    .where((line) => line.isNotEmpty)
    .toList();

String? _value(String ics, String property) => _contentLines(ics)
    .firstWhere((line) => line.startsWith('$property:'), orElse: () => '')
    .replaceFirst('$property:', '');

void main() {
  setUpAll(initializeAppointmentTimeZones);

  group('structure', () {
    test('opens and closes both the calendar and the event', () {
      final lines = _contentLines(
        buildAppointmentIcs(appointment: _appointment()),
      );

      expect(lines.first, 'BEGIN:VCALENDAR');
      expect(lines.last, 'END:VCALENDAR');
      expect(lines, contains('BEGIN:VEVENT'));
      expect(lines, contains('END:VEVENT'));
      expect(lines, contains('VERSION:2.0'));
    });

    test('every line ends with CRLF, including the last', () {
      final ics = buildAppointmentIcs(appointment: _appointment());

      expect(ics.endsWith('END:VCALENDAR\r\n'), isTrue);
      // A bare LF anywhere would be a grammar violation.
      expect(ics.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('the UID is stable across exports and unique per slot', () {
      final first = buildAppointmentIcs(appointment: _appointment());
      final second = buildAppointmentIcs(appointment: _appointment());

      expect(_value(first, 'UID'), _value(second, 'UID'));
      expect(_value(first, 'UID'), 'appt-1-slot-a@echomeet.app');
    });

    test('SEQUENCE tracks the revision so updates are not seen as older', () {
      expect(
        _value(buildAppointmentIcs(appointment: _appointment(revision: 1)),
            'SEQUENCE'),
        '0',
      );
      expect(
        _value(buildAppointmentIcs(appointment: _appointment(revision: 4)),
            'SEQUENCE'),
        '3',
      );
    });

    test('an unconfirmed appointment cannot be exported', () {
      expect(
        () => buildAppointmentIcs(appointment: _appointment(confirmed: false)),
        throwsStateError,
      );
    });

    test('no attendee address is published', () {
      final ics = buildAppointmentIcs(appointment: _appointment());

      expect(ics, isNot(contains('ATTENDEE')));
      expect(ics, isNot(contains('mailto:')));
    });
  });

  group('instants', () {
    test('emits UTC, so the same instant survives any creator zone', () {
      final berlin = buildAppointmentIcs(
        appointment: _appointment(zoneId: 'Europe/Berlin'),
      );
      final newYork = buildAppointmentIcs(
        appointment: _appointment(zoneId: 'America/New_York'),
      );

      expect(_value(berlin, 'DTSTART'), '20260715T070000Z');
      expect(_value(berlin, 'DTSTART'), _value(newYork, 'DTSTART'));
      expect(_value(berlin, 'DTEND'), '20260715T080000Z');
    });

    test('carries no TZID, so no VTIMEZONE block is required', () {
      final ics = buildAppointmentIcs(appointment: _appointment());

      expect(ics, isNot(contains('TZID')));
      expect(ics, isNot(contains('VTIMEZONE')));
    });

    test('a slot spanning a DST transition keeps its real duration', () {
      // 00:30 → 01:30 UTC on the European spring-forward night. Local wall
      // clocks jump, the instants do not.
      final start = DateTime.utc(2026, 3, 29, 0, 30);
      final ics = buildAppointmentIcs(
        appointment: _appointment(
          startAt: start,
          endAt: start.add(const Duration(hours: 1)),
        ),
      );

      expect(_value(ics, 'DTSTART'), '20260329T003000Z');
      expect(_value(ics, 'DTEND'), '20260329T013000Z');
    });

    test('DTSTAMP is the export moment, in UTC', () {
      final ics = buildAppointmentIcs(
        appointment: _appointment(),
        now: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

      expect(_value(ics, 'DTSTAMP'), '20260102T030405Z');
    });
  });

  group('text escaping', () {
    test('escapes the characters the grammar reserves', () {
      final ics = buildAppointmentIcs(
        appointment: _appointment(
          title: r'Review; notes, and a \ backslash',
          description: 'First line\nSecond line',
        ),
      );

      expect(_value(ics, 'SUMMARY'), r'Review\; notes\, and a \\ backslash');
      expect(_value(ics, 'DESCRIPTION'), r'First line\nSecond line');
    });

    test('a backslash is not double-escaped by the later replacements', () {
      final ics = buildAppointmentIcs(
        appointment: _appointment(title: r'a\;b'),
      );

      // Not `a\\\\\;b`, which is what escaping in the wrong order produces.
      expect(_value(ics, 'SUMMARY'), r'a\\\;b');
    });

    test('a CRLF in the source becomes one escaped newline', () {
      final ics = buildAppointmentIcs(
        appointment: _appointment(description: 'One\r\nTwo'),
      );

      expect(_value(ics, 'DESCRIPTION'), r'One\nTwo');
    });
  });

  group('folding', () {
    test('no content line exceeds 75 octets', () {
      final ics = buildAppointmentIcs(
        appointment: _appointment(
          title: 'A' * 200,
          description: 'B' * 400,
        ),
      );

      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
    });

    test('unfolding restores the original value exactly', () {
      final title = 'Long ${'planning ' * 20}session';
      final ics = buildAppointmentIcs(appointment: _appointment(title: title));

      expect(_value(ics, 'SUMMARY'), title);
    });

    test('German and Albanian characters survive folding intact', () {
      // Each of these is two octets in UTF-8, so a naive character-based fold
      // splits one in half and corrupts it.
      final description = 'Präsentation über Prüfungen ${'ë ç ü ö ä ß ' * 12}';
      final ics = buildAppointmentIcs(
        appointment: _appointment(description: description),
      );

      for (final line in ics.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
      expect(_value(ics, 'DESCRIPTION'), description);
    });

    test('a multi-byte character exactly on the boundary is not split', () {
      // Pad so a two-octet character straddles octet 75.
      for (var padding = 60; padding < 80; padding++) {
        final description = '${'x' * padding}ë tail';
        final ics = buildAppointmentIcs(
          appointment: _appointment(description: description),
        );

        for (final line in ics.split('\r\n')) {
          expect(utf8.encode(line).length, lessThanOrEqualTo(75));
        }
        expect(
          _value(ics, 'DESCRIPTION'),
          description,
          reason: 'padding $padding corrupted the value',
        );
      }
    });
  });

  group('file name', () {
    test('slugifies the title', () {
      expect(
        appointmentIcsFileName(_appointment(title: 'Quarterly Review 2026')),
        'quarterly-review-2026.ics',
      );
    });

    test('drops characters a filesystem would reject', () {
      expect(
        appointmentIcsFileName(_appointment(title: r'Q1: plan/review *draft*')),
        'q1-plan-review-draft.ics',
      );
    });

    test('falls back when nothing usable remains', () {
      expect(appointmentIcsFileName(_appointment(title: '///')),
          'appointment.ics');
    });

    test('bounds the length', () {
      final name = appointmentIcsFileName(_appointment(title: 'word ' * 40));

      expect(name.length, lessThanOrEqualTo(64));
      expect(name.endsWith('.ics'), isTrue);
    });
  });
}
