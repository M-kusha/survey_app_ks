import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DST wall-time resolution', () {
    test('rejects Berlin skipped local hour', () {
      final resolution = resolveAppointmentWallTime(
        zoneId: 'Europe/Berlin',
        wallTime: DateTime.utc(2026, 3, 29, 2, 30),
      );
      expect(resolution.isNonexistent, isTrue);
    });

    test('requires a choice for Berlin repeated local hour', () {
      final resolution = resolveAppointmentWallTime(
        zoneId: 'Europe/Berlin',
        wallTime: DateTime.utc(2026, 10, 25, 2, 30),
      );

      expect(resolution.isAmbiguous, isTrue);
      expect(resolution.instants, hasLength(2));
      expect(
        resolution.instants.last.difference(resolution.instants.first),
        const Duration(hours: 1),
      );
      expect(
        resolution.instants.map(
          (instant) => appointmentUtcOffset(instant, 'Europe/Berlin'),
        ),
        ['UTC+02:00', 'UTC+01:00'],
      );
    });

    test('also detects New York repeated hour', () {
      final resolution = resolveAppointmentWallTime(
        zoneId: 'America/New_York',
        wallTime: DateTime.utc(2026, 11, 1, 1, 30),
      );
      expect(resolution.instants, hasLength(2));
      expect(resolution.instants.first, isNot(resolution.instants.last));
      expect(
        resolution.instants.map(
          (instant) => appointmentTimeInZone(instant, 'America/New_York').hour,
        ),
        everyElement(1),
      );
    });
  });

  test('Berlin and New York view the same instant deterministically', () {
    final instant = DateTime.utc(2026, 8, 10, 9);
    final berlin = appointmentTimeInZone(instant, 'Europe/Berlin');
    final newYork = appointmentTimeInZone(instant, 'America/New_York');

    expect((berlin.hour, berlin.minute), (11, 0));
    expect((newYork.hour, newYork.minute), (5, 0));
    expect(berlin.isAtSameMomentAs(newYork), isTrue);
  });

  test(
    'strict deadline is open 1 ms before, closed at and after expiration',
    () {
      final now = DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true);
      final earliest = DateTime.fromMillisecondsSinceEpoch(1002, isUtc: true);

      expect(
        isValidAppointmentDeadline(
          now: now,
          expirationAt: now,
          slotStarts: [earliest],
        ),
        isFalse,
      );
      expect(
        isValidAppointmentDeadline(
          now: now,
          expirationAt: DateTime.fromMillisecondsSinceEpoch(1001, isUtc: true),
          slotStarts: [earliest],
        ),
        isTrue,
      );
      expect(
        isValidAppointmentDeadline(
          now: now,
          expirationAt: earliest,
          slotStarts: [earliest],
        ),
        isFalse,
      );
      expect(
        isValidAppointmentDeadline(
          now: DateTime.fromMillisecondsSinceEpoch(1002, isUtc: true),
          expirationAt: DateTime.fromMillisecondsSinceEpoch(1001, isUtc: true),
          slotStarts: [earliest.add(const Duration(milliseconds: 1))],
        ),
        isFalse,
      );
    },
  );

  test('leap day and midnight crossing preserve real duration', () {
    final resolution = resolveAppointmentWallTime(
      zoneId: 'Europe/Berlin',
      wallTime: DateTime.utc(2028, 2, 29, 23, 30),
    );
    final start = resolution.single!;
    final end = start.add(const Duration(hours: 1));
    final endWall = appointmentTimeInZone(end, 'Europe/Berlin');

    expect((endWall.year, endWall.month, endWall.day), (2028, 3, 1));
    expect((endWall.hour, endWall.minute), (0, 30));
    expect(end.difference(start), const Duration(hours: 1));
  });

  test('year boundary preserves the 23:30 to 00:30 real-hour range', () {
    final resolution = resolveAppointmentWallTime(
      zoneId: 'Europe/Berlin',
      wallTime: DateTime.utc(2026, 12, 31, 23, 30),
    );
    final start = resolution.single!;
    final end = start.add(const Duration(hours: 1));
    final endWall = appointmentTimeInZone(end, 'Europe/Berlin');

    expect((endWall.year, endWall.month, endWall.day), (2027, 1, 1));
    expect((endWall.hour, endWall.minute), (0, 30));
    expect(end.difference(start), const Duration(hours: 1));
  });

  test('sorting uses instants rather than repeated wall labels', () {
    final repeated = resolveAppointmentWallTime(
      zoneId: 'Europe/Berlin',
      wallTime: DateTime.utc(2026, 10, 25, 2, 30),
    ).instants.reversed.toList();

    repeated.sort();
    expect(repeated.first.isBefore(repeated.last), isTrue);
  });
}
