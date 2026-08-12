import 'dart:io';

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/participants/appointment_participants_pdf.dart';
import 'package:echomeet/appointments/participants/participant_overview.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pdf/pdf.dart';

import '../support/load_translations.dart';

TimeSlot _slot(int index, {bool confirmed = false}) => TimeSlot(
  slotId: 'slot-$index',
  start: DateTime.utc(2026, 9, 14 + index, 9 + index * 2),
  end: DateTime.utc(2026, 9, 14 + index, 11 + index * 2),
  isConfirmed: confirmed,
);

const _names = [
  'Arta Krasniqi',
  'Lukas Brandt',
  'Emily Hartley',
  'Blerim Gashi',
  'Sophie Weber',
  'James Okonkwo',
  'Drilon Berisha',
  'Hannah Vogel',
  'Oliver Bennett',
  'Rina Hoxha',
  'Maximilian Schuster',
  'Vlora Rexhepi',
];

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadAppTranslations();
    await initializeDateFormatting();
  });

  test('renders both meeting exports for inspection', () async {
    final slots = [_slot(0), _slot(1, confirmed: true), _slot(2)];
    final appointment = Appointment(
      companyId: 'company',
      createdBy: 'organizer',
      appointmentId: 'meeting',
      title: 'Quarterly planning',
      description: 'Goals, headcount and what we drop. Two hours, camera on.',
      zoneId: 'Europe/Berlin',
      availableTimeSlots: slots,
      expirationDate: DateTime.utc(2026, 9, 10),
      creationDate: DateTime.utc(2026, 8, 20),
      revision: 3,
      confirmedSlotId: 'slot-1',
    );

    final votes = <AppointmentParticipants>[];
    for (final (index, name) in _names.indexed) {
      if (index >= 10) continue;
      for (final (position, slot) in slots.indexed) {
        if ((index + position) % 4 == 3) continue;
        votes.add(
          AppointmentParticipants(
            userId: 'user-$index',
            userName: name,
            slotId: slot.slotId,
            status: VoteStatus.values[(index + position) % 3].wireName,
            participated: true,
          ),
        );
      }
    }

    final overview = buildParticipantOverview(
      slots: slots,
      votes: votes,
      memberNames: {
        for (final (index, name) in _names.indexed) 'user-$index': name,
      },
      unknownName: 'Unknown',
    );

    final directory = Directory('build/pdf-preview')
      ..createSync(recursive: true);

    for (final scope in ParticipantExportScope.values) {
      final document = await AppointmentParticipantsPdf(
        appointment: appointment,
        overview: overview,
        scope: scope,
      ).buildDocument(PdfPageFormat.a4, 'en', viewerZone: 'Europe/Berlin');

      final bytes = await document.save();
      File('${directory.path}/meeting-${scope.name}.pdf')
          .writeAsBytesSync(bytes);
      expect(bytes.length, greaterThan(2000));
    }
  });
}
