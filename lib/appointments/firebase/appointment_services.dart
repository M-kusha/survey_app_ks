import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/edit/appointment_edit_conflict.dart';
import 'package:echomeet/utilities/firebase_services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentService {
  AppointmentService({
    FirebaseServices? userServices,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _userServices = userServices ?? FirebaseServices(),
       _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseServices _userServices;

  Future<String> createAppointment(Appointment appointment) async {
    final companyId = await _userServices.currentCompanyId();
    if (companyId == null) {
      throw StateError(
        'Cannot create an appointment: the signed-in user has no companyId.',
      );
    }
    final userId = _auth.currentUser?.uid;
    if (userId == null) {
      throw StateError('Cannot create an appointment while signed out.');
    }

    final document = _db.collection('appointments').doc();

    appointment.appointmentId = document.id;
    appointment.companyId = companyId;
    appointment.createdBy = userId;

    await document.set(appointment.toFirestore());

    return document.id;
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final appointment = _db.collection('appointments').doc(appointmentId);
    final votes = await appointment.collection('participants').get();

    const chunkSize = 400;
    for (var start = 0; start < votes.docs.length; start += chunkSize) {
      final batch = _db.batch();
      final end = (start + chunkSize).clamp(0, votes.docs.length);
      for (final doc in votes.docs.sublist(start, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    await appointment.delete();
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

  Future<void> saveVotes({
    required String userId,
    required String appointmentId,
    required String userName,
    required List<({TimeSlot slot, String status})> votes,
  }) async {
    if (votes.isEmpty) return;

    final appointmentRef = _db.collection('appointments').doc(appointmentId);
    final batch = _db.batch();

    for (final vote in votes) {
      final slot = vote.slot;
      final participantId =
          '$userId-${slot.start.toIso8601String()}-${slot.end.toIso8601String()}';
      batch.set(appointmentRef.collection('participants').doc(participantId), {
        'userName': userName,
        'date': slot.start.toIso8601String(),
        // Store the complete offered slot. Security rules can then require an
        // exact match with availableTimeSlots instead of trusting arbitrary
        // start/end values supplied by the client.
        'timeSlot': slot.toFirestore(),
        'status': vote.status,
        'userId': userId,
        'participated': true,
      });
    }

    // The trusted vote-create trigger derives participantUserIds on the parent.
    // Keeping the client out of that field closes the parent-only forgery path.
    await batch.commit();
  }

  Future<void> updateAppointment({
    required String appointmentId,
    required AppointmentEditBaseline baseline,
    required String title,
    required String description,
    required List<TimeSlot> availableTimeSlots,
    required DateTime expirationDate,
    required bool reopenVoting,
  }) async {
    final docRef = _db.collection('appointments').doc(appointmentId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final current = snapshot.data();
      if (!snapshot.exists || current == null) {
        throw const AppointmentEditMissing();
      }
      if (!baseline.matchesFirestore(current)) {
        throw const AppointmentEditConflict();
      }

      final currentConfirmed =
          ((current['confirmedTimeSlots'] as List<dynamic>?) ?? const []).map(
            (slot) => Map<String, dynamic>.from(slot as Map),
          );
      final confirmation = mergeAppointmentConfirmation(
        editedSlots: availableTimeSlots.map((slot) => slot.toFirestore()),
        currentConfirmedSlots: currentConfirmed,
        reopenVoting: reopenVoting,
      );

      transaction.update(docRef, {
        'title': title,
        'description': description,
        'availableDates': availableTimeSlots
            .map((slot) => slot.start.toIso8601String())
            .toList(),
        'availableTimeSlots': confirmation.availableSlots,
        'expirationDate': expirationDate.toIso8601String(),
        'expirationAt': Timestamp.fromDate(expirationDate),
        'confirmedTimeSlots': confirmation.confirmedSlots,
      });
    });
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

  Stream<Appointment?> watchAppointment(String appointmentId) {
    return _db.collection('appointments').doc(appointmentId).snapshots().map((
      snapshot,
    ) {
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return null;
      return Appointment.fromFirestore(data);
    });
  }

  Stream<List<AppointmentParticipants>> watchParticipants(
    String appointmentId,
  ) {
    return _db
        .collection('appointments')
        .doc(appointmentId)
        .collection('participants')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (document) =>
                    AppointmentParticipants.fromFirestore(document.data()),
              )
              .toList(growable: false),
        );
  }

  Future<String> fetchUserNameById(String userId) async {
    var userDoc = await FirebaseFirestore.instance
        .collection('memberDirectory')
        .doc(userId)
        .get();
    if (userDoc.exists) {
      return userDoc.data()?['fullName'] ?? 'Unknown';
    } else {
      return 'Unknown';
    }
  }

  Future<String> fetchProfileImage(String userId) async {
    if (userId.isEmpty) return '';

    // Members who registered before the directory existed have no document
    // here yet. Absent is an ordinary state, not a failure.
    final member = await FirebaseFirestore.instance
        .collection('memberDirectory')
        .doc(userId)
        .get();
    return member.data()?['profileImage'] as String? ?? '';
  }

  Future<void> confirmTimeSlot(
    String appointmentId,
    TimeSlot timeSlotToConfirm,
  ) async {
    final docRef = _db.collection('appointments').doc(appointmentId);
    final start = timeSlotToConfirm.start.toIso8601String();
    final end = timeSlotToConfirm.end.toIso8601String();

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();
      if (!snapshot.exists || data == null) {
        throw StateError('Appointment not found.');
      }

      final available = ((data['availableTimeSlots'] as List<dynamic>?) ?? [])
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();
      final confirmed = ((data['confirmedTimeSlots'] as List<dynamic>?) ?? [])
          .map((slot) => Map<String, dynamic>.from(slot as Map))
          .toList();

      if (confirmed.isNotEmpty) {
        final alreadySelected =
            confirmed.length == 1 &&
            confirmed.single['start'] == start &&
            confirmed.single['end'] == end;
        if (alreadySelected) return;
        throw StateError('Another time slot is already confirmed.');
      }

      Map<String, dynamic>? selected;
      for (final slot in available) {
        final isSelected = slot['start'] == start && slot['end'] == end;
        slot['isConfirmed'] = isSelected;
        if (isSelected) selected = slot;
      }
      if (selected == null) {
        throw StateError('Time slot not found in appointment.');
      }

      transaction.update(docRef, {
        'availableTimeSlots': available,
        'confirmedTimeSlots': [Map<String, dynamic>.from(selected)],
      });
    });
  }

  Future<List<AppointmentParticipants>> fetchAllParticipants(
    String appointmentId,
  ) async {
    final snapshot = await _db
        .collection('appointments')
        .doc(appointmentId)
        .collection('participants')
        .get();

    return snapshot.docs
        .map((doc) => AppointmentParticipants.fromFirestore(doc.data()))
        .toList();
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
