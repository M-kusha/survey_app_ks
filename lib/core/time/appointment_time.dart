import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

bool _timeZonesInitialized = false;

void initializeAppointmentTimeZones() {
  if (_timeZonesInitialized) return;
  timezone_data.initializeTimeZones();
  _timeZonesInitialized = true;
}

String requireIanaTimeZone(String zoneId) {
  initializeAppointmentTimeZones();
  timezone.getLocation(zoneId);
  return zoneId;
}

DateTime canonicalAppointmentInstant(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(
      value.millisecondsSinceEpoch,
      isUtc: true,
    );

class WallTimeResolution {
  const WallTimeResolution(this.instants);

  final List<DateTime> instants;

  bool get isNonexistent => instants.isEmpty;
  bool get isAmbiguous => instants.length > 1;
  DateTime? get single => instants.length == 1 ? instants.single : null;
}

WallTimeResolution resolveAppointmentWallTime({
  required String zoneId,
  required DateTime wallTime,
}) {
  initializeAppointmentTimeZones();
  final location = timezone.getLocation(zoneId);
  final wallUtc = DateTime.utc(
    wallTime.year,
    wallTime.month,
    wallTime.day,
    wallTime.hour,
    wallTime.minute,
    wallTime.second,
    wallTime.millisecond,
  );
  final offsets = location.zones.map((zone) => zone.offset).toSet();
  final candidates = <int, DateTime>{};

  for (final offset in offsets) {
    final instant = wallUtc.subtract(offset);
    final zoned = timezone.TZDateTime.from(instant, location);
    if (_sameWallClock(zoned, wallUtc)) {
      candidates[instant.millisecondsSinceEpoch] = instant.toUtc();
    }
  }

  final ordered = candidates.values.toList()
    ..sort((left, right) => left.compareTo(right));
  return WallTimeResolution(List.unmodifiable(ordered));
}

DateTime appointmentTimeInZone(DateTime instant, String zoneId) {
  initializeAppointmentTimeZones();
  return timezone.TZDateTime.from(
    canonicalAppointmentInstant(instant),
    timezone.getLocation(zoneId),
  );
}

String appointmentUtcOffset(DateTime instant, String zoneId) {
  final offset = appointmentTimeInZone(instant, zoneId).timeZoneOffset;
  return appointmentOffsetLabel(offset);
}

String appointmentOffsetLabel(Duration offset) {
  final sign = offset.isNegative ? '-' : '+';
  final minutes = offset.inMinutes.abs();
  return 'UTC$sign${(minutes ~/ 60).toString().padLeft(2, '0')}:'
      '${(minutes % 60).toString().padLeft(2, '0')}';
}

String formatAppointmentRange({
  required DateTime startAt,
  required DateTime endAt,
  String? zoneId,
  String? locale,
}) {
  final start = zoneId == null
      ? canonicalAppointmentInstant(startAt).toLocal()
      : appointmentTimeInZone(startAt, zoneId);
  final end = zoneId == null
      ? canonicalAppointmentInstant(endAt).toLocal()
      : appointmentTimeInZone(endAt, zoneId);

  final sameDay = _sameCalendarDay(start, end);
  final day = DateFormat.MMMEd(locale).format(start);
  final from = DateFormat.jm(locale).format(start);
  final endTime = DateFormat.jm(locale).format(end);
  final to = sameDay
      ? endTime
      : '${DateFormat.MMMEd(locale).format(end)} $endTime';

  return '$day · $from – $to';
}

bool isValidAppointmentDeadline({
  required DateTime now,
  required DateTime expirationAt,
  required Iterable<DateTime> slotStarts,
}) {
  if (!canonicalAppointmentInstant(now).isBefore(expirationAt)) return false;
  if (slotStarts.isEmpty) return false;
  final earliest = slotStarts.reduce(
    (left, right) => left.isBefore(right) ? left : right,
  );
  return expirationAt.isBefore(earliest);
}

DateTime defaultAppointmentDeadline({
  required DateTime now,
  required DateTime earliestStartAt,
}) {
  final canonicalNow = canonicalAppointmentInstant(now);
  final earliest = canonicalAppointmentInstant(earliestStartAt);
  final availableMilliseconds = earliest
      .difference(canonicalNow)
      .inMilliseconds;
  if (availableMilliseconds <= 1) {
    throw ArgumentError('The first appointment slot must be in the future.');
  }
  final oneHourBefore = earliest.subtract(const Duration(hours: 1));
  if (oneHourBefore.isAfter(canonicalNow)) return oneHourBefore;
  return canonicalNow.add(Duration(milliseconds: availableMilliseconds ~/ 2));
}

bool _sameWallClock(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day &&
    left.hour == right.hour &&
    left.minute == right.minute &&
    left.second == right.second &&
    left.millisecond == right.millisecond;

bool _sameCalendarDay(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;
