import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  final String zoneId;

  final TextStyle? style;
  final TextStyle? secondaryStyle;
  final int? maxLines;

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
