library;

import 'package:echomeet/appointments/appointment_data.dart';

enum VoteStatus {
  yes,
  maybe,
  no;

  int get weight => switch (this) {
    VoteStatus.yes => 2,
    VoteStatus.maybe => 1,
    VoteStatus.no => 0,
  };

  String get wireName => switch (this) {
    VoteStatus.yes => 'joined',
    VoteStatus.maybe => 'maybe',
    VoteStatus.no => 'declined',
  };

  static VoteStatus? fromWire(String? value) => switch (value) {
    'joined' => VoteStatus.yes,
    'maybe' => VoteStatus.maybe,
    'declined' => VoteStatus.no,
    _ => null,
  };
}

typedef SlotKey = ({DateTime start, DateTime end});

SlotKey slotKeyOf(TimeSlot slot) => (start: slot.start, end: slot.end);

class SlotTally {
  const SlotTally({
    required this.start,
    this.end,
    required this.yes,
    required this.maybe,
    required this.no,
  });

  final DateTime start;
  final DateTime? end;
  final int yes;
  final int maybe;
  final int no;

  int get responses => yes + maybe + no;

  int get score => yes * VoteStatus.yes.weight + maybe;

  bool matches(TimeSlot slot) =>
      start == slot.start && (end == null || end == slot.end);
}

class AppointmentTally {
  const AppointmentTally({required this.slots, required this.leader});

  final List<SlotTally> slots;

  final SlotTally? leader;

  SlotTally? forSlot(TimeSlot slot) =>
      slots.where((tally) => tally.matches(slot)).firstOrNull;

  bool get isTied {
    final best = leader?.score;
    if (best == null || best == 0) return false;
    return slots.where((tally) => tally.score == best).length > 1;
  }
}

AppointmentTally tallyVotes(
  List<TimeSlot> slots,
  List<AppointmentParticipants> votes,
) {
  final byUser = <String, Map<SlotKey, VoteStatus>>{};

  for (final vote in votes) {
    final status = VoteStatus.fromWire(vote.status);
    if (status == null) continue;

    (byUser[vote.userId] ??= {})[slotKeyOf(vote.timeSlot)] = status;
  }

  final tallies = [
    for (final slot in slots)
      () {
        var yes = 0;
        var maybe = 0;
        var no = 0;

        for (final perSlot in byUser.values) {
          switch (perSlot[slotKeyOf(slot)]) {
            case VoteStatus.yes:
              yes++;
            case VoteStatus.maybe:
              maybe++;
            case VoteStatus.no:
              no++;
            case null:
              break;
          }
        }

        return SlotTally(
          start: slot.start,
          end: slot.end,
          yes: yes,
          maybe: maybe,
          no: no,
        );
      }(),
  ];

  return AppointmentTally(slots: tallies, leader: _leaderOf(tallies));
}

SlotTally? _leaderOf(List<SlotTally> tallies) {
  SlotTally? best;

  for (final tally in tallies) {
    if (tally.score == 0) continue;
    if (best == null ||
        tally.score > best.score ||
        (tally.score == best.score &&
            (tally.start.isBefore(best.start) ||
                (tally.start == best.start &&
                    tally.end != null &&
                    best.end != null &&
                    tally.end!.isBefore(best.end!))))) {
      best = tally;
    }
  }

  return best;
}

Map<SlotKey, VoteStatus> votesOf(
  String userId,
  List<AppointmentParticipants> votes,
) {
  return {
    for (final vote in votes)
      if (vote.userId == userId && VoteStatus.fromWire(vote.status) != null)
        slotKeyOf(vote.timeSlot): VoteStatus.fromWire(vote.status)!,
  };
}
