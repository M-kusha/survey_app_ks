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
  });

  final DateTime startAt;
  final DateTime? endAt;
  final String zoneId;
  final TextStyle? style;
  final TextStyle? secondaryStyle;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final deviceZone = context.watch<DeviceTimeZone?>()?.zoneId;
    final locale =
        Localizations.maybeLocaleOf(context)?.toLanguageTag() ??
        Intl.defaultLocale ??
        'en';
    final viewer = _format(startAt, endAt, zoneId: deviceZone, locale: locale);
    final creator = _format(startAt, endAt, zoneId: zoneId, locale: locale);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${'appointment_your_time'.tr()}: $viewer '
          '(${_zoneAndOffsets(startAt, endAt, deviceZone)})',
          style: style,
          maxLines: maxLines,
          overflow: maxLines == null ? null : TextOverflow.ellipsis,
        ),
        Text(
          '${'appointment_organizer_time'.tr()}: $creator '
          '(${_zoneAndOffsets(startAt, endAt, zoneId)})',
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

  static String _zoneAndOffsets(
    DateTime startAt,
    DateTime? endAt,
    String? zoneId,
  ) {
    String offsetFor(DateTime instant) => zoneId == null
        ? appointmentOffsetLabel(
            canonicalAppointmentInstant(instant).toLocal().timeZoneOffset,
          )
        : appointmentUtcOffset(instant, zoneId);

    final startOffset = offsetFor(startAt);
    final endOffset = endAt == null ? startOffset : offsetFor(endAt);
    final offsets = startOffset == endOffset
        ? startOffset
        : '$startOffset → $endOffset';
    return zoneId == null ? offsets : '$zoneId, $offsets';
  }
}
