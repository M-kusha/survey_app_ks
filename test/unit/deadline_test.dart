import 'package:echomeet/core/time/deadline.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2025, 3, 10, 22, 30);

  group('urgency', () {
    test('later tonight is today, not tomorrow', () {
      final deadline = deadlineFor(DateTime(2025, 3, 10, 23, 59), now: now);
      expect(deadline.urgency, DeadlineUrgency.imminent);
      expect(deadline.days, 0);
      expect(deadline.labelKey, 'deadline_today');
    });

    test('early tomorrow is tomorrow, even though it is hours away', () {
      final deadline = deadlineFor(DateTime(2025, 3, 11, 1), now: now);
      expect(deadline.days, 1);
      expect(deadline.labelKey, 'deadline_tomorrow');
    });

    test('spring-forward tomorrow remains one calendar day away', () {
      final beforeJump = appointmentTimeInZone(
        DateTime.utc(2026, 3, 28, 11),
        'Europe/Berlin',
      );
      final afterJump = appointmentTimeInZone(
        DateTime.utc(2026, 3, 29, 10),
        'Europe/Berlin',
      );

      final deadline = deadlineFor(afterJump, now: beforeJump);
      expect(deadline.days, 1);
      expect(deadline.labelKey, 'deadline_tomorrow');
    });

    test('within the week is soon', () {
      final deadline = deadlineFor(DateTime(2025, 3, 14), now: now);
      expect(deadline.urgency, DeadlineUrgency.soon);
      expect(deadline.labelKey, 'deadline_in_days');
    });

    test('beyond a week is distant', () {
      final deadline = deadlineFor(DateTime(2025, 4, 20), now: now);
      expect(deadline.urgency, DeadlineUrgency.distant);
    });

    test('a moment ago has already passed', () {
      final deadline = deadlineFor(
        now.subtract(const Duration(minutes: 1)),
        now: now,
      );
      expect(deadline.urgency, DeadlineUrgency.passed);
      expect(deadline.isPassed, isTrue);
      expect(deadline.labelKey, 'deadline_closed');
    });

    test('the exact deadline instant is already closed', () {
      expect(deadlineFor(now, now: now).isPassed, isTrue);
    });
  });

  group('progress', () {
    test('is half way at the midpoint of the window', () {
      final deadline = deadlineFor(
        DateTime(2025, 3, 20),
        now: DateTime(2025, 3, 15),
        openedAt: DateTime(2025, 3, 10),
      );
      expect(deadline.progress, closeTo(0.5, 0.01));
    });

    test('is full once the deadline has passed', () {
      final deadline = deadlineFor(
        DateTime(2025, 3, 1),
        now: now,
        openedAt: DateTime(2025, 2, 1),
      );
      expect(deadline.progress, 1);
    });

    test(
      'reports zero rather than a nonsense fraction without an open date',
      () {
        final deadline = deadlineFor(DateTime(2025, 3, 20), now: now);
        expect(deadline.progress, 0);
      },
    );

    test('survives a created date after the deadline', () {
      final deadline = deadlineFor(
        DateTime(2025, 3, 20),
        now: now,
        openedAt: DateTime(2025, 4, 1),
      );
      expect(deadline.progress, 0);
    });

    test('never exceeds one', () {
      final deadline = deadlineFor(
        DateTime(2025, 3, 11),
        now: DateTime(2025, 3, 10, 23),
        openedAt: DateTime(2025, 3, 10, 22),
      );
      expect(deadline.progress, lessThanOrEqualTo(1));
    });
  });

  group('nearest refresh boundary', () {
    test('selects the nearest future deadline regardless of input order', () {
      final nearest = nearestFutureDeadline([
        now.add(const Duration(hours: 5)),
        now.subtract(const Duration(minutes: 1)),
        now.add(const Duration(minutes: 20)),
      ], now: now);

      expect(nearest, now.add(const Duration(minutes: 20)));
    });

    test('ignores boundaries that have already crossed', () {
      expect(
        nearestFutureDeadline([
          now,
          now.subtract(const Duration(seconds: 1)),
        ], now: now),
        isNull,
      );
    });
  });
}
