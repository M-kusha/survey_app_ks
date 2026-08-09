library;

enum DeadlineUrgency { distant, soon, imminent, passed }

class Deadline {
  const Deadline._({
    required this.urgency,
    required this.days,
    required this.progress,
  });

  final DeadlineUrgency urgency;

  final int days;

  final double progress;

  bool get isPassed => urgency == DeadlineUrgency.passed;

  String get labelKey => switch (urgency) {
    DeadlineUrgency.passed => 'deadline_closed',
    DeadlineUrgency.imminent =>
      days == 0 ? 'deadline_today' : 'deadline_tomorrow',
    _ => 'deadline_in_days',
  };
}

Deadline deadlineFor(
  DateTime closesAt, {
  required DateTime now,
  DateTime? openedAt,
}) {
  final remaining = closesAt.difference(now);

  if (!remaining.isNegative) {
    final days = _calendarDaysBetween(now, closesAt);

    return Deadline._(
      urgency: switch (days) {
        <= 1 => DeadlineUrgency.imminent,
        <= 7 => DeadlineUrgency.soon,
        _ => DeadlineUrgency.distant,
      },
      days: days,
      progress: _progress(openedAt: openedAt, closesAt: closesAt, now: now),
    );
  }

  return const Deadline._(
    urgency: DeadlineUrgency.passed,
    days: 0,
    progress: 1,
  );
}

int _calendarDaysBetween(DateTime from, DateTime to) {
  final start = DateTime(from.year, from.month, from.day);
  final end = DateTime(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

double _progress({
  required DateTime? openedAt,
  required DateTime closesAt,
  required DateTime now,
}) {
  if (openedAt == null || !openedAt.isBefore(closesAt)) return 0;

  final total = closesAt.difference(openedAt).inSeconds;
  final elapsed = now.difference(openedAt).inSeconds;
  return (elapsed / total).clamp(0.0, 1.0);
}
