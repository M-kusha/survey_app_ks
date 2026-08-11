import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/time_slot_editor.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:flutter_test/flutter_test.dart';

Appointment definition({int revision = 0, String? confirmedSlotId}) {
  final start = DateTime.utc(2026, 9, 1, 9);
  return Appointment(
    appointmentId: '',
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
    creationDate: DateTime.utc(2026, 8, 1),
    revision: revision,
    confirmedSlotId: confirmedSlotId,
  );
}

void main() {
  test('create sends the exact trusted callable envelope', () async {
    late Map<String, dynamic> captured;
    final service = AppointmentService(
      appointmentIdFactory: () => 'appointment-a',
      definitionCallable: (payload) async {
        captured = payload;
        return {'appointmentId': 'appointment-a', 'revision': 1};
      },
    );
    final appointment = definition();

    expect(await service.createAppointment(appointment), 'appointment-a');
    expect(captured.keys, {'action', 'appointmentId', 'definition'});
    expect(captured['action'], 'create');
    expect(captured['appointmentId'], 'appointment-a');
    expect(appointment.revision, 1);
  });

  test('update binds expected revision and explicit reopen intent', () async {
    late Map<String, dynamic> captured;
    final service = AppointmentService(
      definitionCallable: (payload) async {
        captured = payload;
        return {'appointmentId': 'appointment-a', 'revision': 8};
      },
    );
    final appointment = definition(revision: 7, confirmedSlotId: 'slot-a')
      ..appointmentId = 'appointment-a';

    expect(
      await service.updateAppointment(
        appointment: appointment,
        reopenVoting: true,
      ),
      8,
    );
    expect(captured.keys, {
      'action',
      'appointmentId',
      'expectedRevision',
      'reopenVoting',
      'definition',
    });
    expect(captured['action'], 'update');
    expect(captured['expectedRevision'], 7);
    expect(captured['reopenVoting'], isTrue);
    expect(appointment.confirmedSlotId, isNull);
  });

  test('invalid callable results fail closed', () async {
    final service = AppointmentService(
      appointmentIdFactory: () => 'appointment-a',
      definitionCallable: (_) async => {
        'appointmentId': 'other',
        'revision': 1,
      },
    );
    expect(service.createAppointment(definition()), throwsA(isA<StateError>()));
  });

  test('noncanonical callable revision fails closed', () async {
    final service = AppointmentService(
      appointmentIdFactory: () => 'appointment-a',
      definitionCallable: (_) async => {
        'appointmentId': 'appointment-a',
        'revision': 0,
      },
    );
    expect(service.createAppointment(definition()), throwsA(isA<StateError>()));
  });

  test('retiming creates a new slot identity while no-op edit retains it', () {
    final slot = definition().availableTimeSlots.single;

    expect(
      appointmentSlotIdAfterEdit(
        existing: slot,
        startAt: slot.startAt,
        endAt: slot.endAt,
        idFactory: () => 'new-slot',
      ),
      slot.slotId,
    );
    expect(
      appointmentSlotIdAfterEdit(
        existing: slot,
        startAt: slot.startAt.add(const Duration(minutes: 15)),
        endAt: slot.endAt.add(const Duration(minutes: 15)),
        idFactory: () => 'new-slot',
      ),
      'new-slot',
    );
  });
}
