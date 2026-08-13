import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/participants/participant_overview.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:flutter_test/flutter_test.dart';

List<ParticipantRow> matching(ParticipantOverview overview, String query) {
  final needle = query.trim().toLowerCase();
  if (needle.isEmpty) return overview.rows;
  return overview.rows
      .where((row) => row.name.toLowerCase().contains(needle))
      .toList();
}

void main() {
  final slots = [
    TimeSlot(
      slotId: 'slot-a',
      start: DateTime.utc(2026, 5, 4, 9),
      end: DateTime.utc(2026, 5, 4, 10),
    ),
  ];

  ParticipantOverview build() => buildParticipantOverview(
    slots: slots,
    votes: [
      AppointmentParticipants(
        userId: 'user-1',
        userName: 'ignored',
        slotId: 'slot-a',
        status: VoteStatus.yes.wireName,
        participated: true,
      ),
    ],
    memberNames: const {
      'user-1': 'Arta Krasniqi',
      'user-2': 'Lukas Brandt',
      'user-3': 'Emily Hartley',
    },
    unknownName: 'Unknown',
  );

  test('an empty query keeps everyone', () {
    expect(matching(build(), '   ').length, 3);
  });

  test('a partial name matches regardless of case', () {
    expect(
      matching(build(), 'kras').map((row) => row.name),
      ['Arta Krasniqi'],
    );
    expect(matching(build(), 'LUKAS').map((row) => row.name), ['Lukas Brandt']);
  });

  test('searching finds people who have not responded', () {
    final overview = build();
    final found = matching(overview, 'emily').single;

    expect(found.name, 'Emily Hartley');
    expect(
      overview.awaiting.map((row) => row.name),
      contains('Emily Hartley'),
      reason: 'the point of searching is finding who has not answered yet',
    );
  });

  test('no match returns nothing rather than everyone', () {
    expect(matching(build(), 'zzz'), isEmpty);
  });
}
