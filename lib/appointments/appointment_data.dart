import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentParticipants {
  String userId;
  String userName;
  String profileImageUrl;
  DateTime date;
  TimeSlot timeSlot;
  String status;
  bool participated;

  AppointmentParticipants({
    required this.userId,
    required this.userName,
    required this.profileImageUrl,
    required this.date,
    required this.timeSlot,
    required this.status,
    required this.participated,
  });

  void setTimeSlot(TimeSlot newTimeSlot) {
    timeSlot = newTimeSlot;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot.toFirestore(),
      'status': status,
      'participated': participated,
      'profileImageUrl': profileImageUrl,
    };
  }

  static AppointmentParticipants fromFirestore(Map<String, dynamic> map) {
    return AppointmentParticipants(
      userId: map['userId'] as String? ?? 'Unknown',
      userName: map['userName'] as String? ?? 'Unknown',
      date: DateTime.parse(map['date'] as String? ?? '1970-01-01T00:00:00Z'),
      timeSlot: TimeSlot.fromFirestore(
        map['timeSlot'] as Map<String, dynamic>? ?? {},
      ),
      status: map['status'] as String? ?? 'Unknown',
      participated: map['participated'] as bool? ?? false,
      profileImageUrl: map['profileImageUrl'] as String? ?? '',
    );
  }
}

class TimeSlot {
  DateTime start;
  DateTime end;
  DateTime expirationDate;
  bool isConfirmed;

  TimeSlot({
    required this.start,
    required this.end,
    required this.expirationDate,
    this.isConfirmed = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'isConfirmed': isConfirmed,
    };
  }

  static TimeSlot fromFirestore(Map<String, dynamic> map) {
    return TimeSlot(
      start: DateTime.parse(map['start'] as String? ?? '1970-01-01T00:00:00Z'),
      end: DateTime.parse(map['end'] as String? ?? '1970-01-01T00:00:00Z'),
      expirationDate: DateTime.parse(
        map['expirationDate'] as String? ?? '1970-01-01T00:00:00Z',
      ),
      isConfirmed: map['isConfirmed'] as bool? ?? false,
    );
  }
}

class Appointment {
  String? companyId;
  String appointmentId;
  String title;
  String description;
  List<DateTime> availableDates;
  List<TimeSlot> availableTimeSlots = [];
  List<AppointmentParticipants> participants;
  DateTime expirationDate;
  List<TimeSlot> confirmedTimeSlots = [];
  DateTime creationDate;

  List<String> participantUserIds;

  int get participationCount => participantUserIds.length;

  bool hasVoted(String userId) => participantUserIds.contains(userId);

  Appointment({
    this.companyId,
    required this.appointmentId,
    required this.title,
    required this.description,
    required this.participants,
    required this.availableDates,
    required this.availableTimeSlots,
    required this.confirmedTimeSlots,
    required this.expirationDate,
    required this.creationDate,
    this.participantUserIds = const [],
  });

  static Appointment fromFirestore(Map<String, dynamic> map) {
    return Appointment(
      companyId: map['companyId'],
      title: map['title'],
      description: map['description'],
      availableDates: List<DateTime>.from(
        (map['availableDates'] as List<dynamic>).map((d) => DateTime.parse(d)),
      ),
      participants: (map['participants'] as List<dynamic>).map((p) {
        return AppointmentParticipants.fromFirestore(p);
      }).toList(),
      availableTimeSlots: (map['availableTimeSlots'] as List<dynamic>).map((
        ts,
      ) {
        return TimeSlot.fromFirestore(ts);
      }).toList(),
      appointmentId: map['appointmentId'],
      confirmedTimeSlots: (map['confirmedTimeSlots'] as List<dynamic>).map((
        ts,
      ) {
        return TimeSlot.fromFirestore(ts);
      }).toList(),
      expirationDate: DateTime.parse(map['expirationDate']),
      participantUserIds: List<String>.from(
        (map['participantUserIds'] as List<dynamic>?) ?? const [],
      ),

      creationDate: _readDate(map['creationDate']),
    );
  }

  static DateTime _readDate(Object? value) => switch (value) {
    Timestamp() => value.toDate(),
    DateTime() => value,
    String() => DateTime.parse(value),

    _ => DateTime.fromMillisecondsSinceEpoch(0),
  };

  Map<String, dynamic> toFirestore() {
    Map<String, dynamic> data = {
      'companyId': companyId,
      'title': title,
      'description': description,
      'availableDates': availableDates.map((d) => d.toIso8601String()).toList(),
      'participants': participants.map((p) => p.toFirestore()).toList(),
      'availableTimeSlots': availableTimeSlots
          .map((ts) => ts.toFirestore())
          .toList(),
      'appointmentId': appointmentId,
      'expirationDate': expirationDate.toIso8601String(),
      'confirmedTimeSlots': confirmedTimeSlots
          .map((ts) => ts.toFirestore())
          .toList(),
      'participantUserIds': participantUserIds,
      'creationDate': creationDate,
    };

    if (companyId != null) data['companyId'] = companyId;

    return data;
  }

  bool isValid() {
    bool isExpirationDateValid = expirationDate.isAfter(DateTime.now());
    return title.isNotEmpty && description.isNotEmpty && isExpirationDateValid;
  }
}
