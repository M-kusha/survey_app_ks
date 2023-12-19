import 'package:uuid/uuid.dart';

class Participant {
  String userName;
  DateTime date;
  TimeSlot timeSlot;
  String status;

  Participant({
    required this.userName,
    required this.date,
    required this.timeSlot,
    required this.status,
  });

  // Setter method to update timeSlot
  void setTimeSlot(TimeSlot newTimeSlot) {
    timeSlot = newTimeSlot;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userName': userName,
      'date': date.toIso8601String(),
      'timeSlot': timeSlot.toFirestore(),
      'status': status,
    };
  }

  static Participant fromFirestore(Map<String, dynamic> map) {
    return Participant(
      userName: map['userName'],
      date: DateTime.parse(map['date']),
      timeSlot: TimeSlot.fromFirestore(map['timeSlot']),
      status: map['status'],
    );
  }
}

class TimeSlot {
  DateTime start;
  DateTime end;
  DateTime expirationDate;
  String amPm;
  bool isConfirmed;

  TimeSlot(
      {required this.start,
      required this.end,
      required this.expirationDate,
      this.isConfirmed = false,
      this.amPm = ''}) {
    amPm;
  }

  Map<String, dynamic> toFirestore() {
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'expirationDate': expirationDate.toIso8601String(),
      'amPm': amPm,
      'isConfirmed': isConfirmed,
    };
  }

  static TimeSlot fromFirestore(Map<String, dynamic> map) {
    return TimeSlot(
      start: DateTime.parse(map['start']),
      end: DateTime.parse(map['end']),
      expirationDate: DateTime.parse(map['expirationDate']),
      amPm: map['amPm'],
      isConfirmed: map['isConfirmed'],
    );
  }
}

class Survey {
  String title;
  String description;
  List<DateTime> availableDates;
  List<TimeSlot> availableTimeSlots = [];
  String password;
  String id;
  List<Participant> participants = [];
  DateTime expirationDate;
  bool isAnyTimeSlotConfirmed = false;
  bool disableIfYouParticipated = false;
  List<TimeSlot> confirmedTimeSlots = [];

  Survey({
    required this.title,
    required this.description,
    required this.availableDates,
    required this.availableTimeSlots,
    required this.password,
    required this.id,
    required this.expirationDate,
  });

  factory Survey.create({
    required String title,
    required String description,
    required List<DateTime> availableDates,
    required List<TimeSlot> availableTimeSlots,
    required String password,
  }) {
    final String uniqueId = const Uuid().v4();
    return Survey(
      title: title,
      description: description,
      availableDates: availableDates,
      availableTimeSlots: availableTimeSlots,
      password: password,
      id: uniqueId,
      expirationDate: DateTime.now(),
    );
  }
  static Survey fromFirestore(Map<String, dynamic> map) {
    return Survey(
      title: map['title'],
      description: map['description'],
      availableDates: List<DateTime>.from(
          map['availableDates'].map((d) => DateTime.parse(d))),
      availableTimeSlots: List<TimeSlot>.from(
          map['availableTimeSlots'].map((ts) => TimeSlot.fromFirestore(ts))),
      password: map['password'],
      id: map['id'],
      expirationDate: DateTime.parse(map['expirationDate']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'availableDates': availableDates.map((d) => d.toIso8601String()).toList(),
      'availableTimeSlots':
          availableTimeSlots.map((ts) => ts.toFirestore()).toList(),
      'password': password,
      'id': id,
      'participants': participants.map((p) => p.toFirestore()).toList(),
      'expirationDate': expirationDate.toIso8601String(),
      'isAnyTimeSlotConfirmed': isAnyTimeSlotConfirmed,
      'disableIfYouParticipated': disableIfYouParticipated,
      'confirmedTimeSlots':
          confirmedTimeSlots.map((ts) => ts.toFirestore()).toList(),
    };
  }

  // Method to join the survey
  void joinSurvey(String userName, DateTime date, TimeSlot timeSlot) {
    Participant participant = Participant(
      userName: userName,
      date: date,
      timeSlot: timeSlot,
      status: 'joined',
    );
    participants.add(participant);
  }

  // Method to maybe join the survey
  void maybeJoinSurvey(String userName, DateTime date, TimeSlot timeSlot) {
    Participant participant = Participant(
      userName: userName,
      date: date,
      timeSlot: timeSlot,
      status: 'maybe',
    );
    participants.add(participant);
  }

  // Method to not join the survey
  void notJoinSurvey(String userName, DateTime date, TimeSlot timeSlot) {
    Participant participant = Participant(
      userName: userName,
      date: date,
      timeSlot: timeSlot,
      status: 'not joined',
    );
    participants.add(participant);
  }

  // Method to get the list of participants who joined the survey for a particular time slot
  List<String> getJoinedParticipants(TimeSlot timeSlot) {
    List<String> joinedParticipants = [];
    for (var participant in participants) {
      if (participant.status == 'joined' && participant.timeSlot == timeSlot) {
        joinedParticipants.add(participant.userName);
      }
    }
    return joinedParticipants;
  }

  // Method to get the list of participants who maybe joined the survey for a particular time slot
  List<String> getMaybeParticipants(TimeSlot timeSlot) {
    List<String> maybeParticipants = [];
    for (var participant in participants) {
      if (participant.status == 'maybe' && participant.timeSlot == timeSlot) {
        maybeParticipants.add(participant.userName);
      }
    }
    return maybeParticipants;
  }

  // Method to get the list of participants who did not join the survey for a particular time slot
  List<String> getNotJoinedParticipants(TimeSlot timeSlot) {
    List<String> notJoinedParticipants = [];
    for (var participant in participants) {
      if (participant.status == 'not joined' &&
          participant.timeSlot == timeSlot) {
        notJoinedParticipants.add(participant.userName);
      }
    }
    return notJoinedParticipants;
  }
}
