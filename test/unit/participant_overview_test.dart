import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/participants/participant_overview.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:flutter_test/flutter_test.dart';

TimeSlot _slot(String id, int hour) => TimeSlot(
  slotId: id,
  start: DateTime.utc(2026, 7, 15, hour),
  end: DateTime.utc(2026, 7, 15, hour + 1),
);

AppointmentParticipants _vote(
  String userId,
  String slotId,
  VoteStatus status,
) => AppointmentParticipants(
  userId: userId,

  userName: 'spoofed',
  slotId: slotId,
  status: status.wireName,
  participated: true,
);

void main() {
  final slots = [_slot('a', 9), _slot('b', 11)];

  group('rows', () {
    test('a roster member who never voted still appears, as awaiting', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: const [],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.single.userId, 'u1');
      expect(overview.rows.single.hasResponded, isFalse);
      expect(overview.awaitingCount, 1);
      expect(overview.respondedCount, 0);
    });

    test('names come from the directory, never from the vote', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [_vote('u1', 'a', VoteStatus.yes)],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.single.name, 'Bea');
      expect(overview.rows.single.name, isNot('spoofed'));
    });

    test('a removed member who voted keeps a row, flagged as former', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [_vote('gone', 'a', VoteStatus.yes)],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      final former = overview.rows.firstWhere((row) => row.userId == 'gone');
      expect(former.isCurrentMember, isFalse);
      expect(former.name, 'Unknown');
      expect(former.statusFor('a'), VoteStatus.yes);
      expect(overview.totalsBySlotId['a']!.yes, 1);
    });

    test('a current member is flagged as such', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [_vote('u1', 'a', VoteStatus.yes)],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.single.isCurrentMember, isTrue);
    });

    test('one person answering several slots produces one row', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [
          _vote('u1', 'a', VoteStatus.yes),
          _vote('u1', 'b', VoteStatus.no),
        ],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.rows, hasLength(1));
      expect(overview.rows.single.statusFor('a'), VoteStatus.yes);
      expect(overview.rows.single.statusFor('b'), VoteStatus.no);
    });
  });

  group('retired slots', () {
    test('a vote for a slot no longer offered is discarded', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [_vote('u1', 'removed-slot', VoteStatus.yes)],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.single.hasResponded, isFalse);
      expect(overview.awaitingCount, 1);
      expect(
        overview.totalsBySlotId.values.every((total) => total.responses == 0),
        isTrue,
      );
    });

    test('a stale vote does not mark someone as responded', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [
          _vote('u1', 'removed-slot', VoteStatus.yes),
          _vote('u2', 'a', VoteStatus.yes),
        ],
        memberNames: const {'u1': 'Bea', 'u2': 'Cai'},
        unknownName: 'Unknown',
      );

      expect(overview.respondedCount, 1);
      expect(overview.responded.single.userId, 'u2');
    });

    test('an unrecognised status is ignored rather than counted', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: const [
          AppointmentParticipants(
            userId: 'u1',
            userName: 'x',
            slotId: 'a',
            status: 'perhaps',
            participated: true,
          ),
        ],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.single.hasResponded, isFalse);
      expect(overview.totalsBySlotId['a']!.responses, 0);
    });
  });

  group('totals', () {
    test('counts each status per slot independently', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [
          _vote('u1', 'a', VoteStatus.yes),
          _vote('u2', 'a', VoteStatus.yes),
          _vote('u3', 'a', VoteStatus.maybe),
          _vote('u1', 'b', VoteStatus.no),
        ],
        memberNames: const {'u1': 'A', 'u2': 'B', 'u3': 'C'},
        unknownName: 'Unknown',
      );

      final a = overview.totalsBySlotId['a']!;
      expect([a.yes, a.maybe, a.no, a.responses], [2, 1, 0, 3]);
      final b = overview.totalsBySlotId['b']!;
      expect([b.yes, b.maybe, b.no, b.responses], [0, 0, 1, 1]);
    });

    test('every offered slot has totals even with no responses', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: const [],
        memberNames: const {'u1': 'Bea'},
        unknownName: 'Unknown',
      );

      expect(overview.totalsBySlotId.keys, containsAll(['a', 'b']));
      expect(overview.totalsBySlotId['b']!.responses, 0);
    });

    test('row statuses and slot totals always agree', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [
          _vote('u1', 'a', VoteStatus.yes),
          _vote('gone', 'a', VoteStatus.maybe),
        ],
        memberNames: const {'u1': 'Bea', 'u2': 'Cai'},
        unknownName: 'Unknown',
      );

      for (final slot in slots) {
        final counted = overview.rows
            .where((row) => row.statusFor(slot.slotId) != null)
            .length;
        expect(counted, overview.totalsBySlotId[slot.slotId]!.responses);
      }
    });
  });

  group('ordering', () {
    test('responders come before people still awaited', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: [_vote('u3', 'a', VoteStatus.yes)],
        memberNames: const {'u1': 'Anna', 'u2': 'Bea', 'u3': 'Zoe'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.first.userId, 'u3');
      expect(overview.rows.skip(1).map((row) => row.name), ['Anna', 'Bea']);
    });

    test('sorting is case-insensitive by name', () {
      final overview = buildParticipantOverview(
        slots: slots,
        votes: const [],
        memberNames: const {'u1': 'bea', 'u2': 'Anna'},
        unknownName: 'Unknown',
      );

      expect(overview.rows.map((row) => row.name), ['Anna', 'bea']);
    });

    test('an identical name is broken by id, so order is stable', () {
      final first = buildParticipantOverview(
        slots: slots,
        votes: const [],
        memberNames: const {'u2': 'Sam', 'u1': 'Sam'},
        unknownName: 'Unknown',
      );
      final second = buildParticipantOverview(
        slots: slots,
        votes: const [],
        memberNames: const {'u1': 'Sam', 'u2': 'Sam'},
        unknownName: 'Unknown',
      );

      expect(
        first.rows.map((row) => row.userId),
        second.rows.map((row) => row.userId),
      );
      expect(first.rows.map((row) => row.userId), ['u1', 'u2']);
    });
  });

  test('an empty company yields an empty overview, not an error', () {
    final overview = buildParticipantOverview(
      slots: slots,
      votes: const [],
      memberNames: const {},
      unknownName: 'Unknown',
    );

    expect(overview.rows, isEmpty);
    expect(overview.respondedCount, 0);
    expect(overview.awaitingCount, 0);
    expect(overview.totalsBySlotId, hasLength(2));
  });
}
