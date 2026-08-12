import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/time/appointment_time.dart';

class AppointmentParticipants {
  const AppointmentParticipants({
    required this.userId,
    required this.userName,
    required this.slotId,
    required this.status,
    required this.participated,
  });

  final String userId;
  final String userName;
  final String slotId;
  final String status;
  final bool participated;

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'userName': userName,
    'slotId': slotId,
    'status': status,
    'participated': participated,
  };

  factory AppointmentParticipants.fromFirestore(Map<String, dynamic> map) {
    if (!_hasExactKeys(map, const {
      'userId',
      'userName',
      'slotId',
      'status',
      'participated',
    })) {
      throw const FormatException('Vote fields are not canonical.');
    }
    final status = _requiredString(map, 'status');
    if (!const {'joined', 'maybe', 'declined'}.contains(status) ||
        map['participated'] != true) {
      throw const FormatException('Vote state is invalid.');
    }
    return AppointmentParticipants(
      userId: _requiredString(map, 'userId'),
      userName: _requiredString(map, 'userName'),
      slotId: _requiredString(map, 'slotId'),
      status: status,
      participated: true,
    );
  }
}

class TimeSlot {
  TimeSlot({
    required this.slotId,
    required DateTime start,
    required DateTime end,
    this.isConfirmed = false,
  }) : startAt = canonicalAppointmentInstant(start),
       endAt = canonicalAppointmentInstant(end);

  final String slotId;
  final DateTime startAt;
  final DateTime endAt;
  bool isConfirmed;

  DateTime get start => startAt.toLocal();
  DateTime get end => endAt.toLocal();

  Map<String, dynamic> toFirestore() => {
    'slotId': slotId,
    'startAt': Timestamp.fromDate(startAt),
    'endAt': Timestamp.fromDate(endAt),
  };

  factory TimeSlot.fromFirestore(
    Map<String, dynamic> map, {
    String? confirmedSlotId,
  }) {
    if (!_hasExactKeys(map, const {'slotId', 'startAt', 'endAt'})) {
      throw const FormatException('Appointment slot fields are not canonical.');
    }
    final slotId = _requiredString(map, 'slotId');
    final startAt = _requiredTimestamp(map, 'startAt');
    final endAt = _requiredTimestamp(map, 'endAt');
    if (!startAt.isBefore(endAt)) {
      throw const FormatException('Appointment slot duration is invalid.');
    }
    return TimeSlot(
      slotId: slotId,
      start: startAt,
      end: endAt,
      isConfirmed: slotId == confirmedSlotId,
    );
  }
}

class Appointment {
  Appointment({
    this.companyId,
    this.createdBy,
    required this.appointmentId,
    required this.title,
    required this.description,
    required this.zoneId,
    required this.availableTimeSlots,
    required DateTime expirationDate,
    required DateTime creationDate,
    this.revision = 0,
    this.confirmedSlotId,
    this.participantUserIds = const [],
    this.isBeingDeleted = false,
  }) : expirationAt = canonicalAppointmentInstant(expirationDate),
       createdAt = canonicalAppointmentInstant(creationDate) {
    _applyConfirmation();
  }

  static const schemaVersion = 2;

  String? companyId;
  String? createdBy;
  String appointmentId;
  String title;
  String description;
  String zoneId;
  List<TimeSlot> availableTimeSlots;
  DateTime expirationAt;
  DateTime createdAt;
  int revision;
  String? confirmedSlotId;
  List<String> participantUserIds;

  /// Set while the server is taking this appointment apart.
  ///
  /// Deletion is two-phase: the callable stamps the parent, clears the votes,
  /// then removes the parent. Between the stamp and the removal the document is
  /// still readable and still matches every list query, so anything showing it
  /// has to know it is on its way out and drop it.
  final bool isBeingDeleted;

  DateTime get expirationDate => expirationAt.toLocal();
  set expirationDate(DateTime value) {
    expirationAt = canonicalAppointmentInstant(value);
  }

  DateTime get creationDate => createdAt.toLocal();

  List<TimeSlot> get confirmedTimeSlots => confirmedSlotId == null
      ? const []
      : availableTimeSlots
            .where((slot) => slot.slotId == confirmedSlotId)
            .toList(growable: false);

  int get participationCount => participantUserIds.length;

  bool hasVoted(String userId) => participantUserIds.contains(userId);

  void setConfirmedSlot(String? slotId) {
    confirmedSlotId = slotId;
    _applyConfirmation();
  }

  factory Appointment.fromFirestore(Map<String, dynamic> map) {
    if (!_hasExactKeys(
          map,
          const {
            'schemaVersion',
            'revision',
            'appointmentId',
            'companyId',
            'createdBy',
            'title',
            'description',
            'zoneId',
            'expirationAt',
            'slots',
            'slotIds',
            'confirmedSlotId',
            'participantUserIds',
            'createdAt',
          },
          optional: const {'deletionStartedAt'},
        ) ||
        map['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported appointment schema.');
    }
    // Only its presence is read. The instant is the server's own bookkeeping for
    // resuming an interrupted delete, and nothing on screen has any use for it.
    // Still validate it: a value with the right field name but the wrong wire
    // type is an unreadable document, not a legitimate deletion barrier.
    final isBeingDeleted = map.containsKey('deletionStartedAt');
    if (isBeingDeleted && map['deletionStartedAt'] is! Timestamp) {
      throw const FormatException('Appointment deletion state is invalid.');
    }
    final rawConfirmedSlotId = map['confirmedSlotId'];
    if (rawConfirmedSlotId != null && rawConfirmedSlotId is! String) {
      throw const FormatException('Confirmed appointment slot is invalid.');
    }
    final confirmedSlotId = rawConfirmedSlotId as String?;
    final revision = map['revision'];
    if (revision is! int || revision < 1 || revision > 9007199254740991) {
      throw const FormatException('Appointment revision is unavailable.');
    }
    final rawSlots = map['slots'];
    if (rawSlots is! List) {
      throw const FormatException('Appointment slots are unavailable.');
    }
    if (rawSlots.isEmpty || rawSlots.length > 100) {
      throw const FormatException('Appointment slot count is invalid.');
    }
    final slots = <TimeSlot>[];
    for (final slot in rawSlots) {
      if (slot is! Map) {
        throw const FormatException('Appointment slot is invalid.');
      }
      slots.add(
        TimeSlot.fromFirestore(
          Map<String, dynamic>.from(slot),
          confirmedSlotId: confirmedSlotId,
        ),
      );
    }
    if (map['slotIds'] is! List || map['participantUserIds'] is! List) {
      throw const FormatException('Appointment indexes are unavailable.');
    }
    final slotIds = List<String>.from(map['slotIds'] as List);
    if (slotIds.length != slots.length ||
        slotIds.toSet().length != slotIds.length ||
        slots.indexed.any((entry) => entry.$2.slotId != slotIds[entry.$1]) ||
        (confirmedSlotId != null && !slotIds.contains(confirmedSlotId))) {
      throw const FormatException('Appointment slot IDs are inconsistent.');
    }
    final rawParticipants = map['participantUserIds'] as List;
    if (rawParticipants.any(
          (id) => id is! String || id.isEmpty || id.contains('/'),
        ) ||
        rawParticipants.toSet().length != rawParticipants.length) {
      throw const FormatException('Appointment participants are invalid.');
    }
    final description = map['description'];
    if (description is! String ||
        description.trim().isEmpty ||
        description.length > 5000) {
      throw const FormatException('Appointment description is invalid.');
    }

    return Appointment(
      companyId: _requiredString(map, 'companyId'),
      createdBy: _requiredString(map, 'createdBy'),
      appointmentId: _requiredString(map, 'appointmentId'),
      title: _requiredString(map, 'title'),
      description: description,
      zoneId: requireIanaTimeZone(_requiredString(map, 'zoneId')),
      availableTimeSlots: slots,
      expirationDate: _requiredTimestamp(map, 'expirationAt'),
      creationDate: _requiredTimestamp(map, 'createdAt'),
      revision: revision,
      confirmedSlotId: confirmedSlotId,
      participantUserIds: List<String>.from(rawParticipants),
      isBeingDeleted: isBeingDeleted,
    );
  }

  Map<String, dynamic> toFirestore() {
    final tenant = companyId;
    final owner = createdBy;
    if (tenant == null || owner == null) {
      throw StateError('A persisted appointment requires its server owner.');
    }
    if (revision < 1 || revision > 9007199254740991) {
      throw StateError('A persisted appointment requires a valid revision.');
    }
    _validateDefinition();
    return {
      'schemaVersion': schemaVersion,
      'revision': revision,
      'appointmentId': appointmentId,
      'companyId': tenant,
      'createdBy': owner,
      'title': title,
      'description': description,
      'zoneId': zoneId,
      'expirationAt': Timestamp.fromDate(expirationAt),
      'slots': availableTimeSlots.map((slot) => slot.toFirestore()).toList(),
      'slotIds': availableTimeSlots.map((slot) => slot.slotId).toList(),
      'confirmedSlotId': confirmedSlotId,
      'participantUserIds': participantUserIds,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toCallableDefinition() {
    _validateDefinition();
    return {
      'title': title,
      'description': description,
      'zoneId': zoneId,
      'expirationAtMillis': expirationAt.millisecondsSinceEpoch,
      'slots': [
        for (final slot in availableTimeSlots)
          {
            'slotId': slot.slotId,
            'startAtMillis': slot.startAt.millisecondsSinceEpoch,
            'endAtMillis': slot.endAt.millisecondsSinceEpoch,
          },
      ],
    };
  }

  bool isValid({DateTime? now}) {
    try {
      _validateDefinition();
    } on Object {
      return false;
    }
    return title.trim().isNotEmpty &&
        description.trim().isNotEmpty &&
        isValidAppointmentDeadline(
          now: now ?? DateTime.now(),
          expirationAt: expirationAt,
          slotStarts: availableTimeSlots.map((slot) => slot.startAt),
        );
  }

  void _validateDefinition() {
    requireIanaTimeZone(zoneId);
    if (title.trim().isEmpty || title.length > 160) {
      throw StateError('Appointment title is invalid.');
    }
    if (description.trim().isEmpty || description.length > 5000) {
      throw StateError('Appointment description is invalid.');
    }
    if (availableTimeSlots.isEmpty || availableTimeSlots.length > 100) {
      throw StateError('Appointment slot count is invalid.');
    }
    final ids = <String>{};
    for (final slot in availableTimeSlots) {
      if (!_identifier.hasMatch(slot.slotId) || !ids.add(slot.slotId)) {
        throw StateError('Appointment slot IDs must be unique.');
      }
      if (!slot.startAt.isBefore(slot.endAt)) {
        throw StateError('Appointment slots require a positive duration.');
      }
    }
    if (confirmedSlotId != null && !ids.contains(confirmedSlotId)) {
      throw StateError('The confirmed slot is not offered.');
    }
    final earliestStartAt = availableTimeSlots
        .map((slot) => slot.startAt)
        .reduce((left, right) => left.isBefore(right) ? left : right);
    if (!expirationAt.isBefore(earliestStartAt)) {
      throw StateError('The appointment deadline is outside its valid range.');
    }
  }

  void _applyConfirmation() {
    for (final slot in availableTimeSlots) {
      slot.isConfirmed = slot.slotId == confirmedSlotId;
    }
  }
}

String _requiredString(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Appointment field $key is unavailable.');
}

DateTime _requiredTimestamp(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is Timestamp) return canonicalAppointmentInstant(value.toDate());
  throw FormatException('Appointment field $key is not a Timestamp.');
}

final _identifier = RegExp(r'^[A-Za-z0-9_-]{1,128}$');

/// Whether [map] carries exactly [expected], allowing only [optional] extras.
///
/// The strictness is the point: an unexpected field means the writer and this
/// reader disagree, and guessing is how a half-migrated document gets shown as
/// if it were whole. [optional] is for the fields the server owns and adds on
/// its own schedule, which are absent far more often than they are present.
bool _hasExactKeys(
  Map<String, dynamic> map,
  Set<String> expected, {
  Set<String> optional = const {},
}) =>
    expected.every(map.containsKey) &&
    map.keys.every((key) => expected.contains(key) || optional.contains(key));
