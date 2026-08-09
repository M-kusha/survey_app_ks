import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/edit/appointment_edit_conflict.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 9, 1, 9);
  final end = start.add(const Duration(hours: 1));
  final deadline = DateTime.utc(2026, 8, 30, 18);

  Appointment appointment() => Appointment(
    companyId: 'company',
    createdBy: 'owner',
    appointmentId: 'appointment',
    title: 'Planning',
    description: 'Quarterly planning',
    participants: [],
    availableDates: [start],
    availableTimeSlots: [
      TimeSlot(start: start, end: end, expirationDate: deadline),
    ],
    confirmedTimeSlots: [],
    expirationDate: deadline,
    creationDate: DateTime.utc(2026, 8, 1),
  );

  test('baseline ignores a remote confirmation but rejects content edits', () {
    final original = appointment();
    final baseline = AppointmentEditBaseline.fromAppointment(original);
    final confirmed = original.availableTimeSlots.single.toFirestore()
      ..['isConfirmed'] = true;
    final remotelyConfirmed = original.toFirestore()
      ..['availableTimeSlots'] = [confirmed]
      ..['confirmedTimeSlots'] = [confirmed]
      ..['participantUserIds'] = ['voter'];

    expect(baseline.matchesFirestore(remotelyConfirmed), isTrue);
    expect(
      baseline.matchesFirestore({...remotelyConfirmed, 'title': 'Changed'}),
      isFalse,
    );
    final movedSlot = Map<String, dynamic>.from(confirmed)
      ..['start'] = start.add(const Duration(minutes: 30)).toIso8601String();
    expect(
      baseline.matchesFirestore({
        ...remotelyConfirmed,
        'availableTimeSlots': [movedSlot],
      }),
      isFalse,
    );
  });

  test(
    'save preserves a remote confirmation still present in edited slots',
    () {
      final slot = appointment().availableTimeSlots.single.toFirestore();
      final confirmed = Map<String, dynamic>.from(slot)..['isConfirmed'] = true;

      final merged = mergeAppointmentConfirmation(
        editedSlots: [slot],
        currentConfirmedSlots: [confirmed],
        reopenVoting: false,
      );

      expect(merged.confirmedSlots, [confirmed]);
      expect(merged.availableSlots, [confirmed]);
    },
  );

  test('save conflicts rather than dropping a remote confirmed slot', () {
    final confirmed = appointment().availableTimeSlots.single.toFirestore()
      ..['isConfirmed'] = true;
    final other = TimeSlot(
      start: start.add(const Duration(days: 1)),
      end: end.add(const Duration(days: 1)),
      expirationDate: deadline,
    ).toFirestore();

    expect(
      () => mergeAppointmentConfirmation(
        editedSlots: [other],
        currentConfirmedSlots: [confirmed],
        reopenVoting: false,
      ),
      throwsA(isA<AppointmentEditConflict>()),
    );
  });

  test('an explicit reopen clears confirmation flags', () {
    final confirmed = appointment().availableTimeSlots.single.toFirestore()
      ..['isConfirmed'] = true;
    final merged = mergeAppointmentConfirmation(
      editedSlots: [confirmed],
      currentConfirmedSlots: [confirmed],
      reopenVoting: true,
    );

    expect(merged.confirmedSlots, isEmpty);
    expect(merged.availableSlots.single['isConfirmed'], isFalse);
  });
}
