import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/participants/appointment_participants_pdf.dart';
import 'package:echomeet/appointments/participants/participant_overview.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

TimeSlot _slot(int index) => TimeSlot(
  slotId: 'slot-$index',
  // Spread across months so every slot renders a distinct, full-length date.
  start: DateTime.utc(2026, 1 + (index % 12), 1 + (index % 27), 9),
  end: DateTime.utc(2026, 1 + (index % 12), 1 + (index % 27), 10),
);

Appointment _appointment(List<TimeSlot> slots) => Appointment(
  companyId: 'company',
  createdBy: 'organizer',
  appointmentId: 'appointment',
  title: 'Quarterly planning',
  description: 'Pick a time',
  zoneId: 'Europe/Berlin',
  availableTimeSlots: slots,
  expirationDate: DateTime.utc(2025, 12, 1),
  creationDate: DateTime.utc(2025, 11, 1),
  revision: 1,
);

AppointmentParticipants _vote(String userId, String slotId, VoteStatus status) =>
    AppointmentParticipants(
      userId: userId,
      userName: 'ignored',
      slotId: slotId,
      status: status.wireName,
      participated: true,
    );

Future<pw.Document> _document({
  required int slotCount,
  required int memberCount,
  required bool vote,
  String? viewerZone,
}) async {
  final slots = [for (var i = 0; i < slotCount; i++) _slot(i)];
  final names = {
    for (var i = 0; i < memberCount; i++) 'user-$i': 'Person $i',
  };
  final overview = buildParticipantOverview(
    slots: slots,
    votes: [
      if (vote)
        for (var i = 0; i < memberCount; i++)
          for (final slot in slots)
            _vote(
              'user-$i',
              slot.slotId,
              VoteStatus.values[(i + slots.indexOf(slot)) % 3],
            ),
    ],
    memberNames: names,
    unknownName: 'Unknown',
  );

  return AppointmentParticipantsPdf(
    appointment: _appointment(slots),
    overview: overview,
  ).buildDocument(PdfPageFormat.a4, 'en', viewerZone: viewerZone);
}

Future<int> _renderedBytes({
  required int slotCount,
  required int memberCount,
  required bool vote,
}) async {
  final slots = [for (var i = 0; i < slotCount; i++) _slot(i)];
  final names = {
    for (var i = 0; i < memberCount; i++)
      'user-$i': 'Person $i Ürsprüngliche Përgjigje',
  };
  final overview = buildParticipantOverview(
    slots: slots,
    votes: [
      if (vote)
        for (var i = 0; i < memberCount; i++)
          for (final slot in slots)
            _vote(
              'user-$i',
              slot.slotId,
              VoteStatus.values[(i + slots.indexOf(slot)) % 3],
            ),
    ],
    memberNames: names,
    unknownName: 'Unknown',
  );

  final document = await AppointmentParticipantsPdf(
    appointment: _appointment(slots),
    overview: overview,
  ).buildDocument(PdfPageFormat.a4, 'en');

  return (await document.save()).length;
}

void main() {
  // `PdfKit.theme()` reads the bundled Inter fonts through the asset bundle.
  TestWidgetsFlutterBinding.ensureInitialized();
  // The app gets these from `GlobalMaterialLocalizations`; a plain test does
  // not, and `DateFormat.yMMMd(locale)` throws without them.
  initializeDateFormatting();

  // A PDF that throws or overflows only fails at export time, on the one page
  // an organizer wanted to print. These render the document for real.
  test('renders a small meeting', () async {
    expect(
      await _renderedBytes(slotCount: 2, memberCount: 3, vote: true),
      greaterThan(0),
    );
  });

  test('renders when nobody has answered', () async {
    expect(
      await _renderedBytes(slotCount: 3, memberCount: 4, vote: false),
      greaterThan(0),
    );
  });

  test('renders a meeting with no members at all', () async {
    expect(
      await _renderedBytes(slotCount: 1, memberCount: 0, vote: false),
      greaterThan(0),
    );
  });

  test('each time gets its own page, so one slot can be handed out', () async {
    // The list for a single time is what an organizer actually uses — printed
    // and taken to that meeting. Running two slots down one page defeats that.
    final document = await _document(
      slotCount: 3,
      memberCount: 2,
      vote: true,
    );

    expect(document.document.pdfPageList.pages, hasLength(3));
  });

  test('people still awaited are their own page, not a footnote', () async {
    final document = await _document(
      slotCount: 2,
      memberCount: 3,
      vote: false,
    );

    expect(document.document.pdfPageList.pages, hasLength(3));
  });

  test('paginates the largest meeting the schema allows', () async {
    // 100 slots is the ceiling `Appointment` enforces. Grouping by time is what
    // makes this layout survive; a person-by-slot matrix could not.
    expect(
      await _renderedBytes(slotCount: 100, memberCount: 25, vote: true),
      greaterThan(0),
    );
  }, timeout: const Timeout(Duration(minutes: 3)));
}
