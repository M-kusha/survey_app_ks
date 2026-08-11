import 'dart:convert';

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/time/appointment_time.dart';

/// Builds an RFC 5545 calendar entry for an appointment's confirmed slot.
///
/// Times are emitted as UTC (`...Z`) rather than as a local time with a `TZID`
/// parameter. Both are valid, but `TZID` obliges the file to carry a matching
/// `VTIMEZONE` block describing that zone's transition rules, and a wrong or
/// missing one shifts the event in the reader's calendar. A UTC instant needs
/// no such block and cannot be misread, so the appointment's `zoneId` stays a
/// display concern and the file stays unambiguous.
///
/// Attendee addresses are deliberately absent. Nothing here requires them, and
/// including them would publish every participant's email to anyone the file is
/// forwarded to.
String buildAppointmentIcs({required Appointment appointment, DateTime? now}) {
  final slot = appointment.confirmedTimeSlots.firstOrNull;
  if (slot == null) {
    throw StateError('An appointment needs a confirmed slot to be exported.');
  }

  // SEQUENCE must not go backwards for a given UID, so it tracks the
  // appointment revision the server already increments on every edit.
  final sequence = appointment.revision < 1 ? 0 : appointment.revision - 1;

  return _fold([
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//EchoMeet//Appointments//EN',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${appointment.appointmentId}-${slot.slotId}@echomeet.app',
    'DTSTAMP:${_utcStamp(now ?? DateTime.now())}',
    'DTSTART:${_utcStamp(slot.startAt)}',
    'DTEND:${_utcStamp(slot.endAt)}',
    'SEQUENCE:$sequence',
    'STATUS:CONFIRMED',
    'TRANSP:OPAQUE',
    'SUMMARY:${_escapeText(appointment.title)}',
    'DESCRIPTION:${_escapeText(appointment.description)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ]);
}

/// A filesystem-safe name for the exported file.
///
/// Titles are free text, so anything outside a conservative set is dropped
/// rather than escaped: Windows rejects several punctuation characters outright
/// and reserves a handful of bare names.
String appointmentIcsFileName(Appointment appointment) {
  final slug = appointment.title
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  final safe = slug.isEmpty ? 'appointment' : slug;
  return '${safe.length <= 60 ? safe : safe.substring(0, 60)}.ics';
}

String _utcStamp(DateTime value) {
  final utc = canonicalAppointmentInstant(value);
  String two(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}${two(utc.month)}'
      '${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}'
      '${two(utc.second)}Z';
}

/// Escapes a TEXT value per RFC 5545 section 3.3.11.
///
/// The backslash is replaced first, otherwise the escapes added for the other
/// characters would themselves be escaped again. A colon needs no escaping in a
/// value, only in a parameter.
String _escapeText(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\n');

/// Folds content lines to the 75-octet limit and joins them with CRLF.
///
/// The limit counts octets, not characters, so folding walks UTF-8 bytes: `ë`
/// and `ü` occupy two each. A split inside a multi-byte sequence would corrupt
/// the character, so a candidate break point moves left off any continuation
/// byte before the line is cut.
String _fold(List<String> lines) {
  final buffer = StringBuffer();
  for (final line in lines) {
    // A CRLF terminates every content line, including the last.
    buffer.write(_foldLine(line));
    buffer.write('\r\n');
  }
  return buffer.toString();
}

String _foldLine(String line) {
  final bytes = utf8.encode(line);
  if (bytes.length <= _octetLimit) return line;

  final chunks = <String>[];
  var offset = 0;
  var limit = _octetLimit;
  while (offset < bytes.length) {
    var end = offset + limit;
    if (end >= bytes.length) {
      chunks.add(utf8.decode(bytes.sublist(offset)));
      break;
    }
    while (end > offset && _isContinuation(bytes[end])) {
      end--;
    }
    chunks.add(utf8.decode(bytes.sublist(offset, end)));
    offset = end;
    // A continuation carries a leading space that counts toward the limit.
    limit = _octetLimit - 1;
  }

  return chunks.first + chunks.skip(1).map((chunk) => '\r\n $chunk').join();
}

bool _isContinuation(int byte) => (byte & 0xC0) == 0x80;

const _octetLimit = 75;
