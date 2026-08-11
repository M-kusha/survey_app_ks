library;

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';

/// One person's answers across every offered slot.
class ParticipantRow {
  const ParticipantRow({
    required this.userId,
    required this.name,
    required this.statusBySlotId,
    required this.isCurrentMember,
  });

  final String userId;

  /// Resolved from the member directory when the person is still a colleague,
  /// otherwise a caller-supplied placeholder. Never the name stored on the
  /// vote: that value is participant-authored and can name someone else.
  final String name;

  final Map<String, VoteStatus> statusBySlotId;

  /// False for someone who voted and has since been removed from the company.
  final bool isCurrentMember;

  bool get hasResponded => statusBySlotId.isNotEmpty;

  VoteStatus? statusFor(String slotId) => statusBySlotId[slotId];
}

/// Per-slot totals. Counts only answers to slots the appointment still offers.
class SlotTotals {
  const SlotTotals({
    required this.slotId,
    required this.yes,
    required this.maybe,
    required this.no,
  });

  final String slotId;
  final int yes;
  final int maybe;
  final int no;

  int get responses => yes + maybe + no;
}

class ParticipantOverview {
  const ParticipantOverview({
    required this.rows,
    required this.totalsBySlotId,
  });

  final List<ParticipantRow> rows;
  final Map<String, SlotTotals> totalsBySlotId;

  int get respondedCount => rows.where((row) => row.hasResponded).length;
  int get awaitingCount => rows.length - respondedCount;

  Iterable<ParticipantRow> get responded => rows.where((r) => r.hasResponded);
  Iterable<ParticipantRow> get awaiting => rows.where((r) => !r.hasResponded);
}

/// Combines the company roster with the votes actually cast.
///
/// The roster is what makes "waiting on three people" answerable, but it is not
/// the whole list: someone who voted and was later removed from the company
/// still has their answer counted in the totals, so they must appear as a row
/// or the numbers on screen would not add up to the numbers beside each slot.
///
/// Votes naming a slot the appointment no longer offers are discarded. Editing
/// an appointment can retire a slot while its votes remain, and counting a
/// choice nobody can see would overstate agreement — the same rule the vote
/// tally already applies.
ParticipantOverview buildParticipantOverview({
  required List<TimeSlot> slots,
  required List<AppointmentParticipants> votes,
  required Map<String, String> memberNames,
  required String unknownName,
}) {
  final offeredSlotIds = {for (final slot in slots) slot.slotId};

  final statusByUser = <String, Map<String, VoteStatus>>{};
  for (final vote in votes) {
    if (!offeredSlotIds.contains(vote.slotId)) continue;
    final status = VoteStatus.fromWire(vote.status);
    if (status == null) continue;
    (statusByUser[vote.userId] ??= <String, VoteStatus>{})[vote.slotId] =
        status;
  }

  final userIds = <String>{...memberNames.keys, ...statusByUser.keys};
  final rows = [
    for (final userId in userIds)
      ParticipantRow(
        userId: userId,
        name: memberNames[userId] ?? unknownName,
        statusBySlotId: Map.unmodifiable(
          statusByUser[userId] ?? const <String, VoteStatus>{},
        ),
        isCurrentMember: memberNames.containsKey(userId),
      ),
  ];

  // Responders first, so the outstanding people are not buried mid-list. Then
  // by name, then by id: without the final key two colleagues sharing a name
  // would swap places between rebuilds.
  rows.sort((left, right) {
    if (left.hasResponded != right.hasResponded) {
      return left.hasResponded ? -1 : 1;
    }
    final byName = left.name.toLowerCase().compareTo(right.name.toLowerCase());
    return byName != 0 ? byName : left.userId.compareTo(right.userId);
  });

  final totals = <String, SlotTotals>{};
  for (final slot in slots) {
    var yes = 0;
    var maybe = 0;
    var no = 0;
    for (final row in rows) {
      switch (row.statusFor(slot.slotId)) {
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
    totals[slot.slotId] = SlotTotals(
      slotId: slot.slotId,
      yes: yes,
      maybe: maybe,
      no: no,
    );
  }

  return ParticipantOverview(
    rows: List.unmodifiable(rows),
    totalsBySlotId: Map.unmodifiable(totals),
  );
}
