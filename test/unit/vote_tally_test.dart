import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';
import 'package:flutter_test/flutter_test.dart';

TimeSlot slot(int day) => TimeSlot(
  start: DateTime(2025, 3, day, 10),
  end: DateTime(2025, 3, day, 11),
  expirationDate: DateTime(2025, 3, 1),
);

AppointmentParticipants vote(
  String userId,
  TimeSlot on,
  VoteStatus status, {
  String name = 'Someone',
}) => AppointmentParticipants(
  userId: userId,
  userName: name,
  profileImageUrl: '',
  date: on.start,
  timeSlot: on,
  status: status.wireName,
  participated: true,
);

void main() {
  final monday = slot(10);
  final tuesday = slot(11);
  final wednesday = slot(12);

  group('wire format', () {
    test('round-trips every status', () {
      for (final status in VoteStatus.values) {
        expect(VoteStatus.fromWire(status.wireName), status);
      }
    });

    test('an unreadable status is not silently a no', () {
      // Counting it as a decline would record somebody as having refused a
      // meeting they never opened.
      expect(VoteStatus.fromWire('garbage'), isNull);
      expect(VoteStatus.fromWire(null), isNull);
    });
  });

  group('counting', () {
    test('counts each answer against its own slot', () {
      final tally = tallyVotes(
        [monday, tuesday],
        [
          vote('a', monday, VoteStatus.yes),
          vote('b', monday, VoteStatus.maybe),
          vote('c', monday, VoteStatus.no),
          vote('a', tuesday, VoteStatus.yes),
        ],
      );

      final first = tally.forSlot(monday)!;
      expect((first.yes, first.maybe, first.no), (1, 1, 1));
      expect(first.responses, 3);
      expect(tally.forSlot(tuesday)!.yes, 1);
    });

    test('matches a vote to its slot by start, not by object identity', () {
      // The screens compared TimeSlot instances with `==`, which the class does
      // not implement — so it was reference equality and only ever worked while
      // the same objects stayed in the widget tree.
      final rebuilt = TimeSlot(
        start: monday.start,
        end: monday.end,
        expirationDate: monday.expirationDate,
      );

      final tally = tallyVotes([monday], [vote('a', rebuilt, VoteStatus.yes)]);
      expect(tally.forSlot(monday)!.yes, 1);
    });

    test('two people with the same name are two votes', () {
      // This is the bug that mattered: every check was `p.userName == userName`,
      // so a second Jan Meier overwrote the first and could see their answer.
      final tally = tallyVotes(
        [monday],
        [
          vote('a', monday, VoteStatus.yes, name: 'Jan Meier'),
          vote('b', monday, VoteStatus.yes, name: 'Jan Meier'),
        ],
      );

      expect(tally.forSlot(monday)!.yes, 2);
    });

    test('one person voting twice on a slot counts once, last wins', () {
      final tally = tallyVotes(
        [monday],
        [vote('a', monday, VoteStatus.yes), vote('a', monday, VoteStatus.no)],
      );

      final result = tally.forSlot(monday)!;
      expect(result.yes, 0);
      expect(result.no, 1);
      expect(result.responses, 1);
    });

    test('a slot nobody answered reports zeros, not absence', () {
      final tally = tallyVotes(
        [monday, tuesday],
        [vote('a', monday, VoteStatus.yes)],
      );
      expect(tally.forSlot(tuesday)!.responses, 0);
    });

    test('votes for a slot that no longer exists are ignored', () {
      // An admin can delete a proposed time after people have voted on it.
      final tally = tallyVotes(
        [monday],
        [vote('a', wednesday, VoteStatus.yes)],
      );
      expect(tally.slots, hasLength(1));
      expect(tally.forSlot(monday)!.responses, 0);
    });
  });

  group('the leader', () {
    test('is the highest score', () {
      final tally = tallyVotes(
        [monday, tuesday],
        [
          vote('a', monday, VoteStatus.maybe),
          vote('b', monday, VoteStatus.maybe),
          vote('a', tuesday, VoteStatus.yes),
          vote('b', tuesday, VoteStatus.yes),
        ],
      );

      expect(tally.leader!.start, tuesday.start);
    });

    test('a yes outweighs a maybe', () {
      final tally = tallyVotes(
        [monday, tuesday],
        [
          vote('a', monday, VoteStatus.yes),
          vote('b', tuesday, VoteStatus.maybe),
        ],
      );
      expect(tally.leader!.start, monday.start);
    });

    test('enough maybes still lose to more people who can actually come', () {
      final tally = tallyVotes(
        [monday, tuesday],
        [
          for (var i = 0; i < 3; i++) vote('m$i', monday, VoteStatus.maybe),
          for (var i = 0; i < 2; i++) vote('y$i', tuesday, VoteStatus.yes),
        ],
      );
      expect(tally.leader!.start, tuesday.start);
    });

    test('is null before anybody has voted', () {
      // Not "the first slot" — a badge on an arbitrary row is worse than none.
      expect(tallyVotes([monday, tuesday], []).leader, isNull);
    });

    test('is null when every answer is a no', () {
      final tally = tallyVotes([monday], [vote('a', monday, VoteStatus.no)]);
      expect(tally.leader, isNull);
    });

    test('breaks a tie on the earlier slot', () {
      final tally = tallyVotes(
        [tuesday, monday],
        [vote('a', monday, VoteStatus.yes), vote('b', tuesday, VoteStatus.yes)],
      );

      expect(tally.leader!.start, monday.start);
      expect(tally.isTied, isTrue);
    });

    test('a clear winner is not reported as tied', () {
      final tally = tallyVotes(
        [monday, tuesday],
        [
          vote('a', monday, VoteStatus.yes),
          vote('b', monday, VoteStatus.yes),
          vote('c', tuesday, VoteStatus.yes),
        ],
      );
      expect(tally.isTied, isFalse);
    });
  });

  group('votesOf', () {
    test('returns only that person, keyed by slot', () {
      final mine = votesOf('a', [
        vote('a', monday, VoteStatus.yes),
        vote('a', tuesday, VoteStatus.no),
        vote('b', monday, VoteStatus.maybe),
      ]);

      expect(mine, {
        monday.start: VoteStatus.yes,
        tuesday.start: VoteStatus.no,
      });
    });

    test('is empty for somebody who has not voted', () {
      expect(votesOf('z', [vote('a', monday, VoteStatus.yes)]), isEmpty);
    });
  });
}
