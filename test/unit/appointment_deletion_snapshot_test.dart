import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/firebase/appointment_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import 'appointment_grouping_test.dart' show makeAppointment;

/// Deleting an appointment is two-phase on the server: it stamps the parent with
/// `deletionStartedAt`, clears the votes underneath, then removes the parent.
///
/// Every open list is subscribed to that parent, so the stamped document arrives
/// as a normal snapshot while the row is still on screen. The reader has to
/// survive it — and it did not: the extra field failed the exact-keys check, the
/// throw escaped the stream callback, and the assignment and notify after it
/// never ran. The delete looked like it had done nothing until the tab was
/// switched and the list was rebuilt from scratch.
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
    // The server owns this field and writes it on its own schedule, so it is
    // part of the schema whether or not the client has any use for it.
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
    // The exact-keys check is the point of the codec. Allowing the deletion
    // marker must not turn it into a check that waves anything through.
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
    // This is the regression that mattered. The old code mapped inside the
    // stream callback, so a single bad document threw past the assignment and
    // the notify, and the screen kept its stale rows in silence.
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
    // List<String>.from throws TypeError for this wire shape. Catching only
    // FormatException therefore leaves another route to the original all-list
    // failure.
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
