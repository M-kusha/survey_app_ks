library;

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/utilities/vote_tally.dart';

class ParticipantRow {
  const ParticipantRow({
    required this.userId,
    required this.name,
    required this.statusBySlotId,
    required this.isCurrentMember,
  });

  final String userId;

  final String name;

  final Map<String, VoteStatus> statusBySlotId;

  final bool isCurrentMember;

  bool get hasResponded => statusBySlotId.isNotEmpty;

  VoteStatus? statusFor(String slotId) => statusBySlotId[slotId];
}

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
  const ParticipantOverview({required this.rows, required this.totalsBySlotId});

  final List<ParticipantRow> rows;
  final Map<String, SlotTotals> totalsBySlotId;

  int get respondedCount => rows.where((row) => row.hasResponded).length;
  int get awaitingCount => rows.length - respondedCount;

  Iterable<ParticipantRow> get responded => rows.where((r) => r.hasResponded);
  Iterable<ParticipantRow> get awaiting => rows.where((r) => !r.hasResponded);
}

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
