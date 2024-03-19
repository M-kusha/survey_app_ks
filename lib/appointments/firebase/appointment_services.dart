import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:uuid/uuid.dart';

class AppointmentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createAppointment(Appointment appointment) async {
    String uniqueId = const Uuid().v1().substring(0, 6);
    appointment.appointmentId = uniqueId;

    var companyId = await getCompanyId();
    if (companyId == null) {
      throw Exception('Company ID not found');
    }

    appointment.companyId = companyId;

    await _db
        .collection('appointments')
        .doc(uniqueId)
        .set(appointment.toFirestore());

    return uniqueId;
  }

  Stream<List<Appointment>> getAppointmentList(String companyId) {
    return _db
        .collection('appointments')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Appointment.fromFirestore(doc.data()))
            .toList());
  }

  Future<bool> isAnyTimeSlotConfirmed(String appointmentId) async {
    final docSnapshot =
        await _db.collection('appointments').doc(appointmentId).get();
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

  Future<void> updateParticipationCount(String appointmentId) async {
    final appointmentRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(appointmentId);

    await appointmentRef.update({
      'participationCount': FieldValue.increment(1),
    });
  }

  Future<void> updateAppointment(Appointment updatedAppointment) async {
    final docRef = FirebaseFirestore.instance
        .collection('appointments')
        .doc(updatedAppointment.appointmentId);

    Map<String, dynamic> updatedData = updatedAppointment.toFirestore();

    await docRef.update(updatedData);
  }

  Future<bool> hasCurrentUserParticipated(
      String appointmentId, String userId) async {
    final participantsSnapshot = await _db
        .collection('appointments')
        .doc(appointmentId)
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .get();

    return participantsSnapshot.docs.isNotEmpty;
  }

  Stream<List<TimeSlot>> streamConfirmedTimeSlots(String appointmentId) {
    return _db.collection('appointments').doc(appointmentId).snapshots().map(
      (snapshot) {
        if (snapshot.exists) {
          var confirmedTimeSlotsData =
              snapshot.data()?['confirmedTimeSlots'] ?? [];
          return confirmedTimeSlotsData
              .map<TimeSlot>((ts) => TimeSlot.fromFirestore(ts))
              .toList();
        } else {
          return [];
        }
      },
    );
  }

  Future<bool> fetchAdminStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    final userId = user.uid;
    final doc = await _db.collection('users').doc(userId).get();
    final role = doc.data()?['role'] as String?;
    return role == 'admin';
  }

  Future<String> fetchUserNameById(String userId) async {
    // Assuming you have a collection 'users' where each documentID is a userId
    var userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      // Adjust 'name' based on your Firestore structure
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
      String appointmentId, TimeSlot timeSlotToConfirm) async {
    final DocumentReference docRef =
        _db.collection('appointments').doc(appointmentId);

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
        (ts) => ts['start'] == timeSlotToConfirm.start.toIso8601String())) {
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
      String appointmentId, TimeSlot timeSlot) async {
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

  Future<String?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('companyId');
  }

  Future<Map<String, bool>> fetchParticipationStatusesForUser(
      List<String> appointmentIds, String userId) async {
    Map<String, bool> participationStatuses = {};

    for (String appointmentId in appointmentIds) {
      final participantsSnapshot = await _db
          .collection('appointments')
          .doc(appointmentId)
          .collection('participants')
          .where('userId', isEqualTo: userId)
          .get();

      participationStatuses[appointmentId] =
          participantsSnapshot.docs.isNotEmpty;
    }

    return participationStatuses;
  }
}
