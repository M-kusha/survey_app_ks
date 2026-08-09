import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:flutter_test/flutter_test.dart';

/// What "still open" has to mean.
///
/// The header counted every meeting whose deadline had not passed, so a screen
/// with three things to answer announced eight — it was also counting the ones
/// already settled on a time and the ones you had answered.
///
/// The grouping itself lives in the screen's State because it needs the
/// provider's participation map. These assert the two rules it turns on, which
/// are properties of the data rather than of the widget.
bool isSettled(Appointment appointment) =>
    appointment.availableTimeSlots.any((slot) => slot.isConfirmed);

bool isLive(Appointment appointment, DateTime now) =>
    appointment.expirationDate.isAfter(now) && !isSettled(appointment);

Appointment make({required DateTime closesAt, bool confirmed = false}) =>
    Appointment(
      appointmentId: 'id',
      title: 'Meeting',
      description: '',
      participants: [],
      availableDates: const [],
      availableTimeSlots: [
        TimeSlot(
          start: DateTime(2025, 3, 20, 10),
          end: DateTime(2025, 3, 20, 11),
          expirationDate: closesAt,
          isConfirmed: confirmed,
        ),
      ],
      confirmedTimeSlots: const [],
      expirationDate: closesAt,
      creationDate: DateTime(2025, 3, 1),
    );

void main() {
  final now = DateTime(2025, 3, 10);

  test('an open meeting with time left is live', () {
    expect(isLive(make(closesAt: DateTime(2025, 3, 15)), now), isTrue);
  });

  test('a meeting past its deadline is not', () {
    expect(isLive(make(closesAt: DateTime(2025, 3, 5)), now), isFalse);
  });

  test('a settled meeting is not live even with time left', () {
    // This is the one the header was getting wrong. Once a time is confirmed
    // the meeting wants nothing from anybody, however long the deadline runs.
    final settled = make(closesAt: DateTime(2025, 3, 15), confirmed: true);
    expect(settled.expirationDate.isAfter(now), isTrue);
    expect(isLive(settled, now), isFalse);
  });

  test('a meeting both settled and expired is not live', () {
    expect(
      isLive(make(closesAt: DateTime(2025, 3, 5), confirmed: true), now),
      isFalse,
    );
  });

  group('participation count', () {
    test('is the number of distinct people, derived from the ids', () {
      final appointment = make(closesAt: DateTime(2025, 3, 15))
        ..participantUserIds = ['a', 'b', 'c'];
      expect(appointment.participationCount, 3);
    });

    test('is zero before anybody votes', () {
      expect(make(closesAt: DateTime(2025, 3, 15)).participationCount, 0);
    });

    test('knows whether a given person has voted', () {
      final appointment = make(closesAt: DateTime(2025, 3, 15))
        ..participantUserIds = ['a'];
      expect(appointment.hasVoted('a'), isTrue);
      expect(appointment.hasVoted('b'), isFalse);
    });

    test('is read back from a stored document', () {
      // The count is what the list row shows. If `participantUserIds` were
      // dropped on the way in, voting would appear to do nothing — which is
      // exactly the symptom that sent me looking.
      //
      // The map is shaped the way Firestore hands one back, not the way
      // `toFirestore` leaves it: the two are not symmetric. `toFirestore`
      // writes `creationDate` as a raw `DateTime` and the SDK turns it into a
      // `Timestamp`, which is what `fromFirestore` then calls `.toDate()` on.
      // Feeding it its own output throws.
      final restored = Appointment.fromFirestore({
        'appointmentId': 'id',
        'title': 'Meeting',
        'description': '',
        'availableDates': <String>[],
        'participants': <dynamic>[],
        'availableTimeSlots': <dynamic>[],
        'confirmedTimeSlots': <dynamic>[],
        'expirationDate': DateTime(2025, 3, 15).toIso8601String(),
        'creationDate': Timestamp.fromDate(DateTime(2025, 3, 1)),
        'participantUserIds': ['a', 'b'],
      });

      expect(restored.participationCount, 2);
      expect(restored.hasVoted('b'), isTrue);
    });

    test('the codec can now read its own output', () {
      // `toFirestore` emits a raw DateTime for creationDate while Firestore
      // hands back a Timestamp. Reading only handled the latter, so a round
      // trip threw — which rules out caching, drafts and offline queues.
      final appointment = make(closesAt: DateTime(2025, 3, 15))
        ..participantUserIds = ['a', 'b'];

      final restored = Appointment.fromFirestore(appointment.toFirestore());
      expect(restored.participationCount, 2);
      expect(restored.creationDate, appointment.creationDate);
    });

    test(
      'a missing creation date does not take the whole document with it',
      () {
        final restored = Appointment.fromFirestore({
          'appointmentId': 'id',
          'title': 'Meeting',
          'description': '',
          'availableDates': <String>[],
          'participants': <dynamic>[],
          'availableTimeSlots': <dynamic>[],
          'confirmedTimeSlots': <dynamic>[],
          'expirationDate': DateTime(2025, 3, 15).toIso8601String(),
        });

        expect(restored.title, 'Meeting');
      },
    );

    test('a document written before the field existed reads as zero', () {
      // `participantUserIds` was added when the counter was fixed; anything
      // created before it is missing the key entirely and must not throw.
      final restored = Appointment.fromFirestore({
        'appointmentId': 'id',
        'title': 'Meeting',
        'description': '',
        'availableDates': <String>[],
        'participants': <dynamic>[],
        'availableTimeSlots': <dynamic>[],
        'confirmedTimeSlots': <dynamic>[],
        'expirationDate': DateTime(2025, 3, 15).toIso8601String(),
        'creationDate': Timestamp.fromDate(DateTime(2025, 3, 1)),
      });

      expect(restored.participationCount, 0);
    });
  });
}
