import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// A meeting time, in the reader's own timezone.
///
/// This used to print two full lines every time — "Your time: …" above
/// "Organizer time: …" — including for the overwhelmingly common case where
/// the reader and the organizer are in the same zone and the two lines were
/// character-for-character identical. Every meeting card carried that twice
/// over, which is what made the lists so heavy.
///
/// Now the time is simply shown converted, with no label, because a time with
/// no qualifier is your own. The organizer's zone appears only when it would
/// actually render a different clock reading — the case where "nine o'clock"
/// is ambiguous and the reader needs to know whose nine.
class AppointmentTimeText extends StatelessWidget {
  const AppointmentTimeText({
    super.key,
    required this.startAt,
    required this.zoneId,
    this.endAt,
    this.style,
    this.secondaryStyle,
    this.maxLines,
    this.showOrganizerZone = true,
  });

  final DateTime startAt;
  final DateTime? endAt;

  /// The organizer's IANA zone, as the meeting was created in.
  final String zoneId;

  final TextStyle? style;
  final TextStyle? secondaryStyle;
  final int? maxLines;

  /// Set false where there is no room for a second line, such as the compact
  /// slot chips on a list card.
  final bool showOrganizerZone;

  @override
  Widget build(BuildContext context) {
    final deviceZone = context.watch<DeviceTimeZone?>()?.zoneId;
    final locale =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ??
        Intl.defaultLocale ??
        'en';

    final viewer = _format(startAt, endAt, zoneId: deviceZone, locale: locale);
    final organizer = _format(startAt, endAt, zoneId: zoneId, locale: locale);

    // A meeting that runs across a daylight-saving change reads as an hour
    // longer or shorter than it is. Naming both offsets is the only warning a
    // reader gets, so it survives the tidy-up.
    final shift = _offsetShift(startAt, endAt, deviceZone);
    final primary = shift == null ? viewer : '$viewer ($shift)';

    final elsewhere = showOrganizerZone && organizer != viewer;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          primary,
          style: style,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
        if (elsewhere)
          Text(
            '${'appointment_organizer_time'.tr()}: $organizer ($zoneId)',
            style: secondaryStyle ?? style,
            maxLines: maxLines,
            overflow: maxLines == null ? null : TextOverflow.ellipsis,
          ),
      ],
    );
  }

  static String _format(
    DateTime startAt,
    DateTime? endAt, {
    String? zoneId,
    required String locale,
  }) {
    if (endAt != null) {
      return formatAppointmentRange(
        startAt: startAt,
        endAt: endAt,
        zoneId: zoneId,
        locale: locale,
      );
    }
    final instant = zoneId == null
        ? canonicalAppointmentInstant(startAt).toLocal()
        : appointmentTimeInZone(startAt, zoneId);
    return DateFormat.yMMMd(locale).add_jm().format(instant);
  }

  /// `UTC+02:00 → UTC+01:00` when the clocks change mid-meeting, else null.
  static String? _offsetShift(
    DateTime startAt,
    DateTime? endAt,
    String? zoneId,
  ) {
    if (endAt == null) return null;

    String offsetFor(DateTime instant) => zoneId == null
        ? appointmentOffsetLabel(
            canonicalAppointmentInstant(instant).toLocal().timeZoneOffset,
          )
        : appointmentUtcOffset(instant, zoneId);

    final start = offsetFor(startAt);
    final end = offsetFor(endAt);
    return start == end ? null : '$start → $end';
  }
}
