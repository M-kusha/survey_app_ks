import 'dart:convert';

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/core/time/appointment_time.dart';

String buildAppointmentIcs({required Appointment appointment, DateTime? now}) {
  final slot = appointment.confirmedTimeSlots.firstOrNull;
  if (slot == null) {
    throw StateError('An appointment needs a confirmed slot to be exported.');
  }

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

String _escapeText(String value) => value
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n')
    .replaceAll('\r', '\\n');

String _fold(List<String> lines) {
  final buffer = StringBuffer();
  for (final line in lines) {
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
    limit = _octetLimit - 1;
  }

  return chunks.first + chunks.skip(1).map((chunk) => '\r\n $chunk').join();
}

bool _isContinuation(int byte) => (byte & 0xC0) == 0x80;

const _octetLimit = 75;
