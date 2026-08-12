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
        .where('schemaVersion', isEqualTo: Appointment.schemaVersion)
        .snapshots()
        .listen(
          (snapshot) {
            if (_disposed ||
                generation != _loadGeneration ||
                _companyId != companyId) {
              return;
            }

            _appointments = readAppointmentSnapshot(
              snapshot.docs.map((doc) => doc.data()),
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
    _refreshParticipationState();
    _notify();
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
            userId != null && userId.isNotEmpty && appointment.hasVoted(userId),
    };
  }

  void _refreshConfirmationState() {
    isAnyTimeSlotConfirmed = {
      for (final appointment in _appointments)
        appointment.appointmentId: appointment.confirmedSlotId != null,
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

List<Appointment> readAppointmentSnapshot(
  Iterable<Map<String, dynamic>> documents, {
  void Function(Object error)? onUnreadable,
}) {
  final appointments = <Appointment>[];
  for (final document in documents) {
    try {
      final appointment = Appointment.fromFirestore(document);
      if (appointment.isBeingDeleted) continue;
      appointments.add(appointment);
    } on Object catch (error) {
      (onUnreadable ?? _reportUnreadable)(error);
    }
  }
  return appointments;
}

void _reportUnreadable(Object error) {
  assert(() {
    debugPrint('Skipped an unreadable appointment: $error');
    return true;
  }());
}
