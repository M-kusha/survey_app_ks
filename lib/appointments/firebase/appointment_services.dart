import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/appointments/appointment_data.dart';
import 'package:echomeet/appointments/edit/appointment_edit_conflict.dart';

typedef AppointmentDefinitionCallable =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> payload);

class AppointmentService {
  AppointmentService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    AppointmentDefinitionCallable? definitionCallable,
    String Function()? appointmentIdFactory,
    AppointmentDefinitionCallable? contentDeletionCallable,
  }) : _firestore = firestore,
       _appointmentIdFactory = appointmentIdFactory,
       _saveDefinition =
           definitionCallable ??
           _firebaseDefinitionCallable(
             functions ?? FirebaseFunctions.instanceFor(region: 'europe-west4'),
           ),
       _deleteContent =
           contentDeletionCallable ??
           ((payload) => _firebaseContentDeletion(functions, payload));

  final FirebaseFirestore? _firestore;
  final String Function()? _appointmentIdFactory;
  final AppointmentDefinitionCallable _saveDefinition;
  final AppointmentDefinitionCallable _deleteContent;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  Future<String> createAppointment(Appointment appointment) async {
    final appointmentId =
        _appointmentIdFactory?.call() ??
        _db.collection('appointments').doc().id;
    appointment.appointmentId = appointmentId;

    final result = await _saveDefinition({
      'action': 'create',
      'appointmentId': appointmentId,
      'definition': appointment.toCallableDefinition(),
    });
    _applyCanonicalResult(appointment, result);
    return appointment.appointmentId;
  }

  Future<int> updateAppointment({
    required Appointment appointment,
    required bool reopenVoting,
  }) async {
    try {
      final result = await _saveDefinition({
        'action': 'update',
        'appointmentId': appointment.appointmentId,
        'expectedRevision': appointment.revision,
        'reopenVoting': reopenVoting,
        'definition': appointment.toCallableDefinition(),
      });
      _applyCanonicalResult(appointment, result);
      if (reopenVoting) appointment.setConfirmedSlot(null);
      return appointment.revision;
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'aborted') throw const AppointmentEditConflict();
      if (error.code == 'not-found') throw const AppointmentEditMissing();
      final blockedRemoval = parseVotedSlotRemovalError(error);
      if (blockedRemoval != null) throw blockedRemoval;
      rethrow;
    }
  }

  Future<void> deleteAppointment(String appointmentId) async {
    final result = await _deleteContent({
      'entityType': 'appointment',
      'entityId': appointmentId,
    });
    _requireDeletionReceipt(result, 'appointment', appointmentId);
  }

  Future<bool> isAnyTimeSlotConfirmed(String appointmentId) async {
    final snapshot = await _db
        .collection('appointments')
        .doc(appointmentId)
        .get();
    final data = snapshot.data();
    return data != null && data['confirmedSlotId'] is String;
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
      final participantId = '$userId-${vote.slot.slotId}';
      batch.set(
        appointmentRef.collection('participants').doc(participantId),
        AppointmentParticipants(
          userId: userId,
          userName: userName,
          slotId: vote.slot.slotId,
          status: vote.status,
          participated: true,
        ).toFirestore(),
      );
    }
    await batch.commit();
  }

  Stream<List<TimeSlot>> streamConfirmedTimeSlots(String appointmentId) => _db
      .collection('appointments')
      .doc(appointmentId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        return data == null
            ? const <TimeSlot>[]
            : Appointment.fromFirestore(data).confirmedTimeSlots;
      });

  Stream<Appointment?> watchAppointment(String appointmentId) => _db
      .collection('appointments')
      .doc(appointmentId)
      .snapshots()
      .map((snapshot) {
        final data = snapshot.data();
        if (data == null) return null;
        final appointment = Appointment.fromFirestore(data);
        return appointment.isBeingDeleted ? null : appointment;
      });

  Stream<List<AppointmentParticipants>> watchParticipants(
    String appointmentId,
  ) => _db
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

  Future<String> fetchUserNameById(String userId) async {
    final userDoc = await _db.collection('memberDirectory').doc(userId).get();
    return userDoc.data()?['fullName'] as String? ?? 'Unknown';
  }

  Stream<Map<String, String>> watchCompanyMemberNames(String companyId) {
    final id = companyId.trim();
    if (id.isEmpty) return Stream.value(const {});

    return _db
        .collection('memberDirectory')
        .where('companyId', isEqualTo: id)
        .snapshots()
        .map((snapshot) {
          final names = <String, String>{};
          for (final document in snapshot.docs) {
            final data = document.data();
            final fullName = data['fullName'];
            if (data['membership'] != 'active') continue;
            if (fullName is String && fullName.trim().isNotEmpty) {
              names[document.id] = fullName.trim();
            }
          }
          return Map.unmodifiable(names);
        });
  }

  Future<int> confirmTimeSlot(
    String appointmentId,
    TimeSlot timeSlotToConfirm, {
    required int expectedRevision,
  }) async {
    final result = await _saveDefinition({
      'action': 'confirm',
      'appointmentId': appointmentId,
      'expectedRevision': expectedRevision,
      'slotId': timeSlotToConfirm.slotId,
    });
    final returnedId = result['appointmentId'];
    final revision = result['revision'];
    if (returnedId != appointmentId || revision is! int || revision < 1) {
      throw StateError('The appointment service returned an invalid result.');
    }
    return revision;
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
        .toList(growable: false);
  }

  Future<List<AppointmentParticipants>> fetchParticipants(
    String appointmentId,
    TimeSlot timeSlot,
  ) async {
    final snapshot = await _db
        .collection('appointments')
        .doc(appointmentId)
        .collection('participants')
        .where('slotId', isEqualTo: timeSlot.slotId)
        .get();
    return snapshot.docs
        .map((doc) => AppointmentParticipants.fromFirestore(doc.data()))
        .toList(growable: false);
  }

  static AppointmentDefinitionCallable _firebaseDefinitionCallable(
    FirebaseFunctions functions,
  ) => (payload) async {
    final result = await functions
        .httpsCallable('saveAppointmentDefinition')
        .call<Map<String, dynamic>>(payload);
    return result.data;
  };

  static Future<Map<String, dynamic>> _firebaseContentDeletion(
    FirebaseFunctions? functions,
    Map<String, dynamic> payload,
  ) async {
    final result =
        await (functions ??
                FirebaseFunctions.instanceFor(region: 'europe-west4'))
            .httpsCallable(
              'deleteContent',
              options: HttpsCallableOptions(
                timeout: const Duration(minutes: 2),
              ),
            )
            .call<Map<String, dynamic>>(payload);
    return result.data;
  }

  static void _requireDeletionReceipt(
    Map<String, dynamic> result,
    String entityType,
    String entityId,
  ) {
    if (result['deleted'] != true ||
        result['entityType'] != entityType ||
        result['entityId'] != entityId) {
      throw const FormatException(
        'The content deletion response was incomplete.',
      );
    }
  }

  static void _applyCanonicalResult(
    Appointment appointment,
    Map<String, dynamic> result,
  ) {
    final appointmentId = result['appointmentId'];
    final revision = result['revision'];
    if (appointmentId is! String ||
        appointmentId != appointment.appointmentId ||
        revision is! int ||
        revision < 1) {
      throw StateError('The appointment service returned an invalid result.');
    }
    appointment.revision = revision;
  }
}
