import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/create/time_slot_editor.dart';
import 'package:echomeet/appointments/edit/appointment_edit_conflict.dart';
import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FunctionError extends FirebaseFunctionsException {
  _FunctionError(String code, String message, dynamic details)
    : super(code: code, message: message, details: details);
}

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

  test(
    'confirmation uses the trusted callable with the current revision',
    () async {
      late Map<String, dynamic> captured;
      final service = AppointmentService(
        definitionCallable: (payload) async {
          captured = payload;
          return {'appointmentId': 'appointment-a', 'revision': 8};
        },
      );
      final slot = definition().availableTimeSlots.single;

      expect(
        await service.confirmTimeSlot(
          'appointment-a',
          slot,
          expectedRevision: 7,
        ),
        8,
      );
      expect(captured, {
        'action': 'confirm',
        'appointmentId': 'appointment-a',
        'expectedRevision': 7,
        'slotId': 'slot-a',
      });
    },
  );

  test('confirmation rejects an inconsistent callable receipt', () async {
    final service = AppointmentService(
      definitionCallable: (_) async => {
        'appointmentId': 'other-appointment',
        'revision': 8,
      },
    );

    expect(
      service.confirmTimeSlot(
        'appointment-a',
        definition().availableTimeSlots.single,
        expectedRevision: 7,
      ),
      throwsA(isA<StateError>()),
    );
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

  test('maps only the exact canonical voted-slot removal error', () async {
    final service = AppointmentService(
      definitionCallable: (_) async => throw _FunctionError(
        'failed-precondition',
        'appointment-voted-slot-removal-blocked',
        {
          'blockedSlotIds': ['slot-a', 'slot-z'],
        },
      ),
    );
    final appointment = definition(revision: 1)
      ..appointmentId = 'appointment-a';

    await expectLater(
      service.updateAppointment(appointment: appointment, reopenVoting: false),
      throwsA(
        isA<AppointmentVotedSlotRemovalBlocked>().having(
          (error) => error.blockedSlotIds,
          'blockedSlotIds',
          ['slot-a', 'slot-z'],
        ),
      ),
    );
  });

  test('rejects malformed voted-slot removal details', () {
    expect(
      parseVotedSlotRemovalError(
        _FunctionError('aborted', 'appointment-voted-slot-removal-blocked', {
          'blockedSlotIds': ['slot-a'],
        }),
      ),
      isNull,
    );
    expect(
      parseVotedSlotRemovalError(
        _FunctionError('failed-precondition', 'different-message', {
          'blockedSlotIds': ['slot-a'],
        }),
      ),
      isNull,
    );
    for (final details in [
      null,
      <String, dynamic>{},
      {'blockedSlotIds': <String>[]},
      {
        'blockedSlotIds': ['slot-z', 'slot-a'],
      },
      {
        'blockedSlotIds': ['slot-a', 'slot-a'],
      },
      {
        'blockedSlotIds': ['bad/id'],
      },
      {
        'blockedSlotIds': ['slot-a'],
        'extra': true,
      },
    ]) {
      expect(
        parseVotedSlotRemovalError(
          _FunctionError(
            'failed-precondition',
            'appointment-voted-slot-removal-blocked',
            details,
          ),
        ),
        isNull,
      );
    }
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
