import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointment_grouping_test.dart' show makeAppointment;

Map<String, dynamic> wireAppointment({
  String id = 'appointment',
  bool deleting = false,
}) {
  final wire = makeAppointment().toFirestore()
    ..['appointmentId'] = id
    ..['slots'] = [
      for (final slot in makeAppointment().availableTimeSlots)
        {
          'slotId': slot.slotId,
          'startAt': Timestamp.fromDate(slot.start),
          'endAt': Timestamp.fromDate(slot.end),
        },
    ];
  if (deleting) {
    wire['deletionStartedAt'] = Timestamp.fromDate(DateTime.utc(2026, 8, 12));
  }
  return wire;
}

void main() {
  test('an appointment being deleted still parses', () {
    final appointment = Appointment.fromFirestore(
      wireAppointment(deleting: true),
    );

    expect(appointment.isBeingDeleted, isTrue);
    expect(appointment.title, 'Planning');
  });

  test('an ordinary appointment is not marked as deleting', () {
    expect(
      Appointment.fromFirestore(wireAppointment()).isBeingDeleted,
      isFalse,
    );
  });

  test('the server deletion marker still has to be a Timestamp', () {
    expect(
      () => Appointment.fromFirestore(
        wireAppointment()..['deletionStartedAt'] = 'not-a-timestamp',
      ),
      throwsFormatException,
    );
  });

  test('a field nobody writes is still rejected', () {
    expect(
      () => Appointment.fromFirestore(
        wireAppointment()..['surpriseField'] = 'whatever',
      ),
      throwsFormatException,
    );
  });

  test('a missing required field is still rejected', () {
    expect(
      () => Appointment.fromFirestore(wireAppointment()..remove('title')),
      throwsFormatException,
    );
  });

  test('a row on its way out leaves the list at once', () {
    final rows = readAppointmentSnapshot([
      wireAppointment(id: 'stays'),
      wireAppointment(id: 'going', deleting: true),
    ]);

    expect(rows.map((row) => row.appointmentId), ['stays']);
  });

  test('one unreadable document does not take the list with it', () {
    final failures = <Object>[];
    final rows = readAppointmentSnapshot([
      wireAppointment(id: 'first'),
      {'schemaVersion': 2, 'appointmentId': 'corrupt'},
      wireAppointment(id: 'third'),
    ], onUnreadable: failures.add);

    expect(rows.map((row) => row.appointmentId), ['first', 'third']);
    expect(failures, hasLength(1));
  });

  test('a non-FormatException decoding failure is isolated to its row', () {
    final wrongType = wireAppointment(id: 'wrong-type')
      ..['slotIds'] = <Object>[7];
    final failures = <Object>[];

    final rows = readAppointmentSnapshot([
      wireAppointment(id: 'first'),
      wrongType,
      wireAppointment(id: 'third'),
    ], onUnreadable: failures.add);

    expect(rows.map((row) => row.appointmentId), ['first', 'third']);
    expect(failures.single, isA<TypeError>());
  });

  test('an empty snapshot reads as an empty list, not a failure', () {
    expect(readAppointmentSnapshot(const []), isEmpty);
  });
}
