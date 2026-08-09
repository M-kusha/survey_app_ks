import 'dart:async';

import 'package:echomeet/appointments/appointment_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppointmentDataProvider extends ChangeNotifier {
  AppointmentDataProvider({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance {
    _authUserId = _auth.currentUser?.uid;
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (_disposed) return;
      if (user?.uid != _authUserId) {
        _authUserId = user?.uid;
        unawaited(clear());
      }
    });
  }

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _appointmentsSubscription;
  Completer<void>? _firstAppointments;
  String? _authUserId;
  String? _companyId;
  String? _participationUserId;
  Set<String> _legacyAppointmentIds = {};
  Map<String, bool> _legacyParticipationStatus = {};
  int _loadGeneration = 0;
  bool _disposed = false;

  List<Appointment> _appointments = [];
  Appointment? _currentAppointment;
  bool _isLoading = false;
  Object? _error;
  Map<String, bool> userParticipationStatus = {};
  Map<String, bool> isAnyTimeSlotConfirmed = {};
  List<Appointment> get appointments => _appointments;

  Appointment? get currentAppointment => _currentAppointment;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> loadAppointments(String companyId) async {
    _authUserId = _auth.currentUser?.uid;
    if (_companyId == companyId &&
        _appointmentsSubscription != null &&
        _error == null) {
      return;
    }

    final generation = ++_loadGeneration;
    final previousSubscription = _appointmentsSubscription;
    _appointmentsSubscription = null;
    _completeFirstAppointments();
    await previousSubscription?.cancel();
    if (_disposed || generation != _loadGeneration) return;

    _companyId = companyId;
    _appointments = [];
    _legacyAppointmentIds = {};
    _legacyParticipationStatus = {};
    userParticipationStatus = {};
    isAnyTimeSlotConfirmed = {};
    _isLoading = true;
    _error = null;
    _notify();

    final firstSnapshot = Completer<void>();
    _firstAppointments = firstSnapshot;
    _appointmentsSubscription = _db
        .collection('appointments')
        .where('companyId', isEqualTo: companyId)
        .snapshots()
        .listen(
          (snapshot) {
            if (_disposed ||
                generation != _loadGeneration ||
                _companyId != companyId) {
              return;
            }

            final legacyAppointmentIds = <String>{};
            _appointments = snapshot.docs.map((doc) {
              final data = doc.data();
              final appointment = Appointment.fromFirestore(data);
              if (!data.containsKey('participantUserIds')) {
                legacyAppointmentIds.add(appointment.appointmentId);
              }
              return appointment;
            }).toList();
            _legacyAppointmentIds = legacyAppointmentIds;
            _legacyParticipationStatus.removeWhere(
              (appointmentId, _) =>
                  !legacyAppointmentIds.contains(appointmentId),
            );
            _refreshDerivedState();
            _isLoading = false;
            _error = null;
            _notify();
            if (!firstSnapshot.isCompleted) firstSnapshot.complete();
            if (identical(_firstAppointments, firstSnapshot)) {
              _firstAppointments = null;
            }
          },
          onError: (Object error, StackTrace stackTrace) {
            if (_disposed ||
                generation != _loadGeneration ||
                _companyId != companyId) {
              return;
            }
            _isLoading = false;
            _error = error;
            _notify();
            if (!firstSnapshot.isCompleted) {
              firstSnapshot.completeError(error, stackTrace);
            }
            if (identical(_firstAppointments, firstSnapshot)) {
              _firstAppointments = null;
            }
          },
        );

    await firstSnapshot.future;
  }

  Future<void> preloadAppointmentsTimeSlotConfirmation() async {
    _refreshConfirmationState();
    _notify();
  }

  Future<void> preloadUserParticipationStatus(String userId) async {
    _participationUserId = userId;
    final companyId = _companyId;
    final generation = _loadGeneration;
    final legacyStatus = <String, bool>{};
    await Future.wait([
      for (final appointment in _appointments)
        if (_legacyAppointmentIds.contains(appointment.appointmentId))
          hasCurrentUserParticipated(appointment.appointmentId, userId).then(
            (participated) =>
                legacyStatus[appointment.appointmentId] = participated,
          ),
    ]);
    if (_disposed ||
        generation != _loadGeneration ||
        _companyId != companyId ||
        _participationUserId != userId) {
      return;
    }
    _legacyParticipationStatus = legacyStatus;
    _refreshParticipationState();
    _notify();
  }

  Future<bool> hasCurrentUserParticipated(
    String appointmentId,
    String userId,
  ) async {
    final participantsSnapshot = await _db
        .collection('appointments')
        .doc(appointmentId)
        .collection('participants')
        .where('userId', isEqualTo: userId)
        .get();

    return participantsSnapshot.docs.isNotEmpty;
  }

  void _refreshDerivedState() {
    _refreshParticipationState();
    _refreshConfirmationState();
  }

  void _refreshParticipationState() {
    final userId = _participationUserId;
    userParticipationStatus = {
      for (final appointment in _appointments)
        appointment.appointmentId:
            userId != null &&
            userId.isNotEmpty &&
            (appointment.hasVoted(userId) ||
                (_legacyParticipationStatus[appointment.appointmentId] ??
                    false)),
    };
  }

  void _refreshConfirmationState() {
    isAnyTimeSlotConfirmed = {
      for (final appointment in _appointments)
        appointment.appointmentId:
            appointment.confirmedTimeSlots.isNotEmpty ||
            appointment.availableTimeSlots.any((slot) => slot.isConfirmed),
    };
  }

  Future<void> clear() async {
    _loadGeneration++;
    final appointmentsSubscription = _appointmentsSubscription;
    _appointmentsSubscription = null;
    _completeFirstAppointments();
    _companyId = null;
    _participationUserId = null;
    _appointments = [];
    _legacyAppointmentIds = {};
    _legacyParticipationStatus = {};
    _currentAppointment = null;
    userParticipationStatus = {};
    isAnyTimeSlotConfirmed = {};
    _isLoading = false;
    _error = null;
    await appointmentsSubscription?.cancel();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _completeFirstAppointments() {
    final firstAppointments = _firstAppointments;
    _firstAppointments = null;
    if (firstAppointments != null && !firstAppointments.isCompleted) {
      firstAppointments.complete();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _completeFirstAppointments();
    unawaited(_authSubscription?.cancel());
    unawaited(_appointmentsSubscription?.cancel());
    super.dispose();
  }
}
