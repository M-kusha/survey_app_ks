import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:survey_app_ks/appointments/appointment_data.dart';
import 'package:survey_app_ks/survey_pages/utilities/survey_questionary_class.dart';

// Assuming Appointment and Participant classes are defined similar to Survey and Participant classes
class AppointmentDataProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  List<Appointment> _appointments = [];
  List<Participant>? _participants;
  Appointment? _currentAppointment;
  bool _isLoading = false;
  Map<String, bool> userParticipationStatus = {};
  List<Appointment> get appointments => _appointments;
  List<Participant>? get participants => _participants;
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
