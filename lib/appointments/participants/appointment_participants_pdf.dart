import 'package:easy_localization/easy_localization.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/participants/participant_overview.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:echomeet/core/time/appointment_time.dart';
import 'package:echomeet/core/time/device_time_zone.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_kit.dart';
import 'package:echomeet/survey_pages/admin/print_pages/pdf_viewer_page.dart';
import 'package:flutter/widgets.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:provider/provider.dart';

class AppointmentParticipantsPdf extends StatelessWidget {
  const AppointmentParticipantsPdf({
    super.key,
    required this.appointment,
    required this.overview,
  });

  final Appointment appointment;
  final ParticipantOverview overview;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();

    final viewerZone = context.watch<DeviceTimeZone?>()?.zoneId;

    return PdfViewerPage(
      title: 'export_participants'.tr(),
      fileName: pdfFileNameFrom([appointment.title, 'all_participants'.tr()]),
      build: (format) => buildDocument(format, locale, viewerZone: viewerZone),
    );
  }

  @visibleForTesting
  Future<pw.Document> buildDocument(
    PdfPageFormat format,
    String locale, {
    String? viewerZone,
  }) async {
    final pdf = pw.Document(theme: await PdfKit.theme());
    final slots = appointment.availableTimeSlots;
    final total = overview.rows.length;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        header: (context) => PdfKit.header(
          title: appointment.title,
          subtitle:
              '${DateFormat.yMMMd(locale).format(DateTime.now())} · '
              '${viewerZone ?? appointment.zoneId}',
        ),
        footer: PdfKit.footer,
        build: (context) => [
          PdfKit.summary([
            PdfKit.stat(
              'participants_responded_short'.tr(),
              '${overview.respondedCount} / $total',
            ),
            PdfKit.stat(
              'awaiting_response'.tr(),
              '${overview.awaitingCount}',
              tint: overview.awaitingCount == 0
                  ? PdfKit.correct
                  : PdfKit.pending,
            ),
            PdfKit.stat('time_slots'.tr(), '${slots.length}'),
          ]),

          for (final (index, slot) in slots.indexed) ...[
            if (index > 0) pw.NewPage(),
            ..._slotSection(slot, locale, viewerZone),
          ],
          if (overview.awaitingCount > 0) ...[
            pw.NewPage(),
            ..._awaitingSection(),
          ],
        ],
      ),
    );

    return pdf;
  }

  List<pw.Widget> _slotSection(TimeSlot slot, String locale, String? viewer) {
    final totals = overview.totalsBySlotId[slot.slotId];
    final byStatus = <VoteStatus, List<ParticipantRow>>{};
    for (final row in overview.rows) {
      final status = row.statusFor(slot.slotId);
      if (status != null) (byStatus[status] ??= []).add(row);
    }

    String at(String? zone) => formatAppointmentRange(
      startAt: slot.startAt,
      endAt: slot.endAt,
      zoneId: zone,
      locale: locale,
    );

    final here = at(viewer);
    final there = at(appointment.zoneId);

    return [
      _heading(
        '$here (${viewer ?? appointment.zoneId})',
        confirmed: slot.isConfirmed,
      ),
      if (here != there)
        _note(
          '${'appointment_organizer_time'.tr()}: $there '
          '(${appointment.zoneId})',
        ),
      if (totals != null && totals.responses == 0)
        _note('nobody_voted_yet'.tr())
      else
        for (final status in VoteStatus.values)
          if (byStatus[status]?.isNotEmpty ?? false)
            _statusGroup(status, byStatus[status]!),
    ];
  }

  List<pw.Widget> _awaitingSection() => [
    _heading('awaiting_response'.tr()),
    for (final row in overview.awaiting) _name(row, PdfKit.muted),
  ];

  pw.Widget _statusGroup(VoteStatus status, List<ParticipantRow> rows) {
    final tint = switch (status) {
      VoteStatus.yes => PdfKit.correct,
      VoteStatus.maybe => PdfKit.pending,
      VoteStatus.no => PdfKit.wrong,
    };

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
          child: pw.Text(
            '${status.labelKey.tr().toUpperCase()}  ${rows.length}',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: tint,
            ),
          ),
        ),
        for (final row in rows) _name(row, tint),
      ],
    );
  }

  pw.Widget _name(ParticipantRow row, PdfColor tint) => pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: 4,
        height: 4,
        margin: const pw.EdgeInsets.only(top: 4, right: 6, left: 2),
        decoration: pw.BoxDecoration(
          color: tint,
          borderRadius: pw.BorderRadius.circular(2),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          row.isCurrentMember
              ? row.name
              : '${row.name} (${'former_member'.tr()})',
          style: const pw.TextStyle(fontSize: 10, color: PdfKit.ink),
        ),
      ),
    ],
  );

  pw.Widget _heading(String text, {bool confirmed = false}) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 14, bottom: 2),
    padding: const pw.EdgeInsets.only(bottom: 3),
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfKit.rule, width: 1)),
    ),
    child: pw.Text(
      confirmed ? '$text  ·  ${'time_slot_confirmed'.tr()}' : text,
      style: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: confirmed ? PdfKit.correct : PdfKit.ink,
      ),
    ),
  );

  pw.Widget _note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 4),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9, color: PdfKit.muted),
    ),
  );
}
