import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment makeAppointment({String? confirmedSlotId}) {
  final start = DateTime.utc(2026, 10, 25, 8);
  return Appointment(
    companyId: 'company',
    createdBy: 'owner',
    appointmentId: 'appointment',
    title: 'Planning',
    description: 'Quarterly planning',
    zoneId: 'Europe/Berlin',
    availableTimeSlots: [
      TimeSlot(
        slotId: 'slot-a',
        start: start,
        end: start.add(const Duration(hours: 1)),
      ),
    ],
    expirationDate: start.subtract(const Duration(days: 1)),
    creationDate: start.subtract(const Duration(days: 30)),
    revision: 4,
    confirmedSlotId: confirmedSlotId,
    participantUserIds: const ['a', 'b'],
  );
}

void main() {
  test('v2 codec round-trips only canonical Timestamp fields', () {
    final original = makeAppointment(confirmedSlotId: 'slot-a');
    final wire = original.toFirestore();
    final restored = Appointment.fromFirestore(wire);

    expect(wire.keys, {
      'schemaVersion',
      'revision',
      'appointmentId',
      'companyId',
      'createdBy',
      'title',
      'description',
      'zoneId',
      'expirationAt',
      'slots',
      'slotIds',
      'confirmedSlotId',
      'participantUserIds',
      'createdAt',
    });
    expect(wire['expirationAt'], isA<Timestamp>());
    expect((wire['slots'] as List).single['startAt'], isA<Timestamp>());
    expect((wire['slots'] as List).single['endAt'], isA<Timestamp>());
    expect(wire.toString(), isNot(contains('T08:00:00')));
    expect(restored.revision, 4);
    expect(restored.zoneId, 'Europe/Berlin');
    expect(restored.availableTimeSlots.single.slotId, 'slot-a');
    expect(restored.confirmedTimeSlots.single.slotId, 'slot-a');
    expect(restored.participationCount, 2);
  });

  test('legacy offset-less documents fail closed', () {
    expect(
      () => Appointment.fromFirestore({
        'schemaVersion': 1,
        'appointmentId': 'legacy',
      }),
      throwsFormatException,
    );
  });

  test('slot ID list must match the canonical slots', () {
    final wire = makeAppointment().toFirestore()..['slotIds'] = ['other'];
    expect(() => Appointment.fromFirestore(wire), throwsFormatException);
  });

  test('the callable definition uses exact epoch-millisecond fields', () {
    final definition = makeAppointment().toCallableDefinition();
    expect(definition.keys, {
      'title',
      'description',
      'zoneId',
      'expirationAtMillis',
      'slots',
    });
    expect(definition['expirationAtMillis'], isA<int>());
    expect((definition['slots'] as List).single, {
      'slotId': 'slot-a',
      'startAtMillis': DateTime.utc(2026, 10, 25, 8).millisecondsSinceEpoch,
      'endAtMillis': DateTime.utc(2026, 10, 25, 9).millisecondsSinceEpoch,
    });
  });

  test('participation state is keyed by canonical user IDs', () {
    final appointment = makeAppointment();
    expect(appointment.hasVoted('a'), isTrue);
    expect(appointment.hasVoted('z'), isFalse);
  });

  test('blank descriptions fail the authoritative client contract', () {
    final appointment = makeAppointment()..description = '   ';
    expect(appointment.isValid(), isFalse);
    expect(appointment.toCallableDefinition, throwsStateError);
  });
}
