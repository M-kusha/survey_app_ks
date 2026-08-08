import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/utilities/firebase_services.dart';

class AppointmentService {
  AppointmentService({FirebaseServices? userServices})
    : _userServices = userServices ?? FirebaseServices();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseServices _userServices;

  Future<String> createAppointment(Appointment appointment) async {
    final companyId = await _userServices.currentCompanyId();
    if (companyId == null) {
      throw StateError(
        'Cannot create an appointment: the signed-in user has no companyId.',
      );
    }

    // A Firestore auto-id, rather than a truncated UUID. The previous
    // `Uuid().v1().substring(0, 6)` kept only 24 bits of a 100ns clock, which
    // wraps roughly every seven minutes — and because the write below is a
    // `set`, a collision silently overwrote an existing appointment.
    final document = _db.collection('appointments').doc();

    appointment.appointmentId = document.id;
    appointment.companyId = companyId;

    await document.set(appointment.toFirestore());

    return document.id;
  }

  Future<bool> isAnyTimeSlotConfirmed(String appointmentId) async {
    final docSnapshot = await _db
        .collection('appointments')
        .doc(appointmentId)
        .get();
    if (docSnapshot.exists) {
      final appointment = Appointment.fromFirestore(docSnapshot.data()!);
      return appointment.confirmedTimeSlots.isNotEmpty;
    }
    return false;
  }

  Future<void> updateParticipantStatus(
    String userId,
    String appointmentId,
    String userName,
    DateTime date,
    TimeSlot timeSlot,
    String status,
  ) async {
    final appointmentRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId);

    final participantId = '$userId-${timeSlot.start}-${timeSlot.end}';

    final participantData = {
      'userName': userName,
      'date': date.toIso8601String(),
      'timeSlot': {
        'start': timeSlot.start.toIso8601String(),
        'end': timeSlot.end.toIso8601String(),
      },
      'status': status,
      'userId': userId,
      'participated': true,
    };

    await appointmentRef
        .collection('participants')
        .doc(participantId)
        .set(participantData);
  }

  /// Records that [userId] has voted on this appointment.
  ///
  /// `arrayUnion` is idempotent: voting again, changing your answer, or
  /// double-tapping the button all leave the set unchanged. This replaced a
  /// `FieldValue.increment(1)`, which counted button presses rather than
  /// people — the total climbed every time somebody reopened an appointment
  /// they had already answered.
  Future<void> registerParticipation(
    String appointmentId,
    String userId,
  ) async {
    await _db.collection('appointments').doc(appointmentId).update({
      'participantUserIds': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> updateAppointment(Appointment updatedAppointment) async {
    final docRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(updatedAppointment.appointmentId);

    Map<String, dynamic> updatedData = updatedAppointment.toFirestore();

    await docRef.update(updatedData);
  }

  Stream<List<TimeSlot>> streamConfirmedTimeSlots(String appointmentId) {
    return _db.collection('appointments').doc(appointmentId).snapshots().map((
      snapshot,
    ) {
      if (snapshot.exists) {
        var confirmedTimeSlotsData =
            snapshot.data()?['confirmedTimeSlots'] ?? [];
        return confirmedTimeSlotsData
            .map<TimeSlot>((ts) => TimeSlot.fromFirestore(ts))
            .toList();
      } else {
        return [];
      }
    });
  }

  Future<String> fetchUserNameById(String userId) async {
    var userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      return userDoc.data()?['fullName'] ?? 'Unknown';
    } else {
      return 'Unknown';
    }
  }

  Future<String> fetchProfileImage(String userId) async {
    if (userId.isNotEmpty) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      return (userDoc.data() as Map<String, dynamic>)['profileImage'] ?? '';
    }
    return '';
  }

  Future<void> confirmTimeSlot(
    String appointmentId,
    TimeSlot timeSlotToConfirm,
  ) async {
    final DocumentReference docRef = _db
        .collection('appointments')
        .doc(appointmentId);

    final DocumentSnapshot docSnapshot = await docRef.get();
    if (!docSnapshot.exists) throw Exception("Appointment not found");

    List<dynamic> availableTimeSlots =
        (docSnapshot.data() as Map<String, dynamic>)['availableTimeSlots'] ??
        [];
    List<dynamic> confirmedTimeSlots =
        (docSnapshot.data() as Map<String, dynamic>)['confirmedTimeSlots'] ??
        [];

    bool found = false;
    for (int i = 0; i < availableTimeSlots.length; i++) {
      if (availableTimeSlots[i]['start'] ==
          timeSlotToConfirm.start.toIso8601String()) {
        availableTimeSlots[i]['isConfirmed'] = true;
        found = true;
        break;
      }
    }

    if (!found) throw Exception("Time slot not found in appointment");

    if (!confirmedTimeSlots.any(
      (ts) => ts['start'] == timeSlotToConfirm.start.toIso8601String(),
    )) {
      confirmedTimeSlots.add({
        'start': timeSlotToConfirm.start.toIso8601String(),
        'end': timeSlotToConfirm.end.toIso8601String(),
        'expirationDate': timeSlotToConfirm.expirationDate.toIso8601String(),
        'isConfirmed': true,
      });
    }

    await docRef.update({
      'availableTimeSlots': availableTimeSlots,
      'confirmedTimeSlots': confirmedTimeSlots,
    });
  }

  Future<List<AppointmentParticipants>> fetchParticipants(
    String appointmentId,
    TimeSlot timeSlot,
  ) async {
    List<AppointmentParticipants> participants = [];

    final participantsRef = _db
        .collection('appointments')
        .doc(appointmentId)
        .collection('participants');
    final snapshot = await participantsRef
        .where('timeSlot.start', isEqualTo: timeSlot.start.toIso8601String())
        .where('timeSlot.end', isEqualTo: timeSlot.end.toIso8601String())
        .get();

    for (var doc in snapshot.docs) {
      participants.add(AppointmentParticipants.fromFirestore(doc.data()));
    }

    return participants;
  }
}
