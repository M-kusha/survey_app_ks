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

enum ParticipantExportScope { allTimes, confirmedOnly }

class AppointmentParticipantsPdf extends StatelessWidget {
  const AppointmentParticipantsPdf({
    super.key,
    required this.appointment,
    required this.overview,
    this.scope = ParticipantExportScope.allTimes,
  });

  final Appointment appointment;
  final ParticipantOverview overview;
  final ParticipantExportScope scope;

  List<TimeSlot> get _slots {
    if (scope == ParticipantExportScope.allTimes) {
      return appointment.availableTimeSlots;
    }
    return appointment.confirmedTimeSlots;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final viewerZone = context.watch<DeviceTimeZone?>()?.zoneId;
    final confirmedOnly = scope == ParticipantExportScope.confirmedOnly;

    return PdfViewerPage(
      title: 'export_participants'.tr(),
      fileName: pdfFileNameFrom([
        appointment.title,
        confirmedOnly ? 'export_confirmed_time'.tr() : 'export_all_times'.tr(),
      ]),
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
    final slots = _slots;
    final zone = viewerZone ?? appointment.zoneId;
    final confirmedOnly = scope == ParticipantExportScope.confirmedOnly;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: format,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (context) => PdfKit.header(
          title: appointment.title,
          subtitle:
              '${DateFormat.yMMMd(locale).format(DateTime.now())} · $zone',
        ),
        footer: PdfKit.footer,
        build: (context) => [
          _summary(slots, confirmedOnly),
          if (appointment.description.trim().isNotEmpty)
            _description(appointment.description),
          for (final (index, slot) in slots.indexed) ...[
            if (index > 0) pw.NewPage(),
            ..._slotSection(slot, locale, viewerZone),
          ],
          if (slots.isEmpty) _emptyNotice(confirmedOnly),
          if (overview.awaitingCount > 0 && !confirmedOnly) ...[
            pw.SizedBox(height: 18),
            ..._awaitingSection(),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _summary(List<TimeSlot> slots, bool confirmedOnly) {
    final total = overview.rows.length;

    return PdfKit.summary([
      PdfKit.stat(
        'participants_responded_short'.tr(),
        '${overview.respondedCount} / $total',
      ),
      PdfKit.stat(
        'awaiting_response'.tr(),
        '${overview.awaitingCount}',
        tint: overview.awaitingCount == 0 ? PdfKit.correct : PdfKit.pending,
      ),
      if (confirmedOnly)
        PdfKit.stat(
          'attending'.tr(),
          '${_attendingCount(slots)}',
          tint: PdfKit.correct,
        )
      else
        PdfKit.stat('time_slots'.tr(), '${slots.length}'),
    ]);
  }

  int _attendingCount(List<TimeSlot> slots) {
    if (slots.isEmpty) return 0;
    final slotId = slots.first.slotId;
    return overview.rows
        .where((row) => row.statusFor(slotId) == VoteStatus.yes)
        .length;
  }

  pw.Widget _description(String description) => pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Text(
      description,
      style: const pw.TextStyle(fontSize: 9.5, color: PdfKit.muted),
    ),
  );

  pw.Widget _emptyNotice(bool confirmedOnly) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: pw.BoxDecoration(
      color: PdfColors.blueGrey50,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      confirmedOnly ? 'no_time_confirmed_yet'.tr() : 'nobody_voted_yet'.tr(),
      style: const pw.TextStyle(fontSize: 10, color: PdfKit.muted),
    ),
  );

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
    final responses = totals?.responses ?? 0;

    return [
      _slotCard(
        when: here,
        zone: viewer ?? appointment.zoneId,
        organiser: here == there
            ? null
            : '${'appointment_organizer_time'.tr()}: $there '
                  '(${appointment.zoneId})',
        confirmed: slot.isConfirmed,
        yes: byStatus[VoteStatus.yes]?.length ?? 0,
        maybe: byStatus[VoteStatus.maybe]?.length ?? 0,
        no: byStatus[VoteStatus.no]?.length ?? 0,
        total: overview.rows.length,
      ),
      if (responses == 0)
        _note('nobody_voted_yet'.tr())
      else
        _voteTable(byStatus),
    ];
  }

  pw.Widget _slotCard({
    required String when,
    required String zone,
    required String? organiser,
    required bool confirmed,
    required int yes,
    required int maybe,
    required int no,
    required int total,
  }) {
    final responses = yes + maybe + no;

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 4, bottom: 10),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        color: confirmed ? PdfKit.correctFill : PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: confirmed ? PdfKit.correct : PdfKit.rule,
          width: confirmed ? 1.2 : 0.8,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      when,
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfKit.ink,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      zone,
                      style: const pw.TextStyle(
                        fontSize: 8.5,
                        color: PdfKit.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (confirmed) _confirmedPill(),
            ],
          ),
          if (organiser != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              organiser,
              style: const pw.TextStyle(fontSize: 8.5, color: PdfKit.muted),
            ),
          ],
          pw.SizedBox(height: 10),
          _proportionBar(yes: yes, maybe: maybe, no: no, total: total),
          pw.SizedBox(height: 6),
          pw.Row(
            children: [
              _legend(VoteStatus.yes, yes),
              _legend(VoteStatus.maybe, maybe),
              _legend(VoteStatus.no, no),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    '$responses / $total',
                    style: const pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfKit.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _confirmedPill() => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: pw.BoxDecoration(
      color: PdfKit.correct,
      borderRadius: pw.BorderRadius.circular(10),
    ),
    child: pw.Text(
      'time_slot_confirmed'.tr().toUpperCase(),
      style: pw.TextStyle(
        fontSize: 7,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
    ),
  );

  pw.Widget _proportionBar({
    required int yes,
    required int maybe,
    required int no,
    required int total,
  }) {
    final counted = yes + maybe + no;
    final missing = (total - counted).clamp(0, total);
    final segments = <(int, PdfColor)>[
      (yes, PdfKit.correct),
      (maybe, PdfKit.pending),
      (no, PdfKit.wrong),
      (missing, PdfKit.rule),
    ].where((segment) => segment.$1 > 0).toList();

    if (segments.isEmpty) {
      return pw.Container(
        height: 8,
        decoration: pw.BoxDecoration(
          color: PdfKit.rule,
          borderRadius: pw.BorderRadius.circular(4),
        ),
      );
    }

    return pw.ClipRRect(
      horizontalRadius: 4,
      verticalRadius: 4,
      child: pw.Container(
        height: 8,
        child: pw.Row(
          children: [
            for (final (count, colour) in segments)
              pw.Expanded(
                flex: count,
                child: pw.Container(color: colour),
              ),
          ],
        ),
      ),
    );
  }

  pw.Widget _legend(VoteStatus status, int count) {
    final tint = _tintOf(status);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(right: 14),
      child: pw.Row(
        children: [
          pw.Container(
            width: 7,
            height: 7,
            margin: const pw.EdgeInsets.only(right: 4),
            decoration: pw.BoxDecoration(
              color: tint,
              borderRadius: pw.BorderRadius.circular(2),
            ),
          ),
          pw.Text(
            '${_shortLabel(status)}  $count',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfKit.ink),
          ),
        ],
      ),
    );
  }

  pw.Widget _voteTable(Map<VoteStatus, List<ParticipantRow>> byStatus) {
    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
        children: [
          _cell('participant'.tr(), header: true),
          _cell('response'.tr(), header: true, align: pw.TextAlign.right),
        ],
      ),
    ];

    var striped = false;
    for (final status in VoteStatus.values) {
      for (final row in byStatus[status] ?? const <ParticipantRow>[]) {
        striped = !striped;
        rows.add(
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: striped ? PdfColors.white : PdfColors.blueGrey50,
            ),
            children: [
              _cell(
                row.isCurrentMember
                    ? row.name
                    : '${row.name} (${'former_member'.tr()})',
                muted: !row.isCurrentMember,
              ),
              _statusCell(status),
            ],
          ),
        );
      }
    }

    return pw.Table(
      border: pw.TableBorder.symmetric(
        inside: const pw.BorderSide(color: PdfKit.rule, width: 0.5),
      ),
      columnWidths: const {
        0: pw.FlexColumnWidth(3),
        1: pw.FlexColumnWidth(1),
      },
      children: rows,
    );
  }

  pw.Widget _cell(
    String text, {
    bool header = false,
    bool muted = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Text(
      header ? text.toUpperCase() : text,
      textAlign: align,
      style: pw.TextStyle(
        fontSize: header ? 7.5 : 10,
        fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
        color: header || muted ? PdfKit.muted : PdfKit.ink,
      ),
    ),
  );

  pw.Widget _statusCell(VoteStatus status) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: pw.BoxDecoration(
          color: _fillOf(status),
          borderRadius: pw.BorderRadius.circular(9),
        ),
        child: pw.Text(
          _shortLabel(status),
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: _tintOf(status),
          ),
        ),
      ),
    ),
  );

  List<pw.Widget> _awaitingSection() => [
    pw.Text(
      '${'awaiting_response'.tr().toUpperCase()}  ${overview.awaitingCount}',
      style: pw.TextStyle(
        fontSize: 8,
        fontWeight: pw.FontWeight.bold,
        color: PdfKit.pending,
      ),
    ),
    pw.SizedBox(height: 6),
    pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final row in overview.awaiting)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfKit.rule, width: 0.8),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              row.name,
              style: const pw.TextStyle(fontSize: 9, color: PdfKit.muted),
            ),
          ),
      ],
    ),
  ];

  pw.Widget _note(String text) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 2, bottom: 6),
    child: pw.Text(
      text,
      style: const pw.TextStyle(fontSize: 9, color: PdfKit.muted),
    ),
  );

  static String _shortLabel(VoteStatus status) => switch (status) {
    VoteStatus.yes => 'vote_short_yes'.tr(),
    VoteStatus.maybe => 'vote_short_maybe'.tr(),
    VoteStatus.no => 'vote_short_no'.tr(),
  };

  static PdfColor _tintOf(VoteStatus status) => switch (status) {
    VoteStatus.yes => PdfKit.correct,
    VoteStatus.maybe => PdfKit.pending,
    VoteStatus.no => PdfKit.wrong,
  };

  static PdfColor _fillOf(VoteStatus status) => switch (status) {
    VoteStatus.yes => PdfKit.correctFill,
    VoteStatus.maybe => PdfColors.orange50,
    VoteStatus.no => PdfKit.wrongFill,
  };
}
