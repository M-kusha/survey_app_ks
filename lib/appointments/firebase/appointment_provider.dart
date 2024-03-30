import 'package:echomeet/appointments/appointment_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentDataProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Appointment> _appointments = [];
  Appointment? _currentAppointment;
  bool _isLoading = false;
  Map<String, bool> userParticipationStatus = {};
  Map<String, bool> isAnyTimeSlotConfirmed = {};
  List<Appointment> get appointments => _appointments;

  Appointment? get currentAppointment => _currentAppointment;
  bool get isLoading => _isLoading;

  Future<void> loadAppointments(String companyId) async {
    _isLoading = true;
    notifyListeners();

    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('appointments')
        .where('companyId', isEqualTo: companyId)
        .get();

    _appointments = snapshot.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      return Appointment.fromFirestore(data);
    }).toList();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> preloadAppointmentsTimeSlotConfirmation() async {
    Map<String, bool> tempStatus = {};

    for (var appointment in _appointments) {
      bool isConfirmed = appointment.confirmedTimeSlots.isNotEmpty;
      tempStatus[appointment.appointmentId] = isConfirmed;
    }
    isAnyTimeSlotConfirmed = tempStatus;

    notifyListeners();
  }

  Future<void> preloadUserParticipationStatus(String userId) async {
    Map<String, bool> tempStatus = {};
    for (var appointment in _appointments) {
      final bool participated =
          await hasCurrentUserParticipated(appointment.appointmentId, userId);
      tempStatus[appointment.appointmentId] = participated;
    }
    userParticipationStatus = tempStatus;
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
}
