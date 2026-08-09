import 'dart:convert';

import 'package:echomeet/appointments/appointment_data.dart';

class AppointmentEditConflict implements Exception {
  const AppointmentEditConflict();
}

class AppointmentEditMissing implements Exception {
  const AppointmentEditMissing();
}

/// Immutable comparison token captured before an edit form can mutate its
/// local slot objects. Confirmation flags are deliberately excluded: a remote
/// confirmation is merged into the save instead of being overwritten.
class AppointmentEditBaseline {
  AppointmentEditBaseline.fromAppointment(Appointment appointment)
    : _signature = _editableSignature({
        'title': appointment.title,
        'description': appointment.description,
        'availableDates': appointment.availableDates
            .map((date) => date.toIso8601String())
            .toList(),
        'availableTimeSlots': appointment.availableTimeSlots
            .map((slot) => slot.toFirestore())
            .toList(),
        'expirationDate': appointment.expirationDate.toIso8601String(),
      });

  final String _signature;

  bool matchesFirestore(Map<String, dynamic> current) =>
      _signature == _editableSignature(current);
}

typedef AppointmentConfirmationMerge = ({
  List<Map<String, dynamic>> availableSlots,
  List<Map<String, dynamic>> confirmedSlots,
});

AppointmentConfirmationMerge mergeAppointmentConfirmation({
  required Iterable<Map<String, dynamic>> editedSlots,
  required Iterable<Map<String, dynamic>> currentConfirmedSlots,
  required bool reopenVoting,
}) {
  final available = [
    for (final slot in editedSlots)
      Map<String, dynamic>.from(slot)..['isConfirmed'] = false,
  ];
  final confirmed = [
    for (final slot in currentConfirmedSlots) Map<String, dynamic>.from(slot),
  ];

  if (reopenVoting || confirmed.isEmpty) {
    return (availableSlots: available, confirmedSlots: []);
  }
  if (confirmed.length != 1) throw const AppointmentEditConflict();

  final selected = confirmed.single;
  final selectedIndex = available.indexWhere(
    (slot) => _sameSlotIgnoringConfirmation(slot, selected),
  );
  if (selectedIndex < 0) throw const AppointmentEditConflict();

  // Use the server's exact map in both fields so Firestore rules can prove the
  // confirmed choice is still one of the offered slots.
  available[selectedIndex] = Map<String, dynamic>.from(selected);
  return (
    availableSlots: available,
    confirmedSlots: [Map<String, dynamic>.from(selected)],
  );
}

String _editableSignature(Map<String, dynamic> data) {
  final rawDates = data['availableDates'];
  final rawSlots = data['availableTimeSlots'];
  return jsonEncode({
    'title': data['title'],
    'description': data['description'],
    'availableDates': rawDates is Iterable
        ? rawDates.map(_dateWireValue).toList()
        : const <String>[],
    'availableTimeSlots': rawSlots is Iterable
        ? rawSlots.map((raw) {
            final slot = Map<String, dynamic>.from(raw as Map);
            return {
              'start': _dateWireValue(slot['start']),
              'end': _dateWireValue(slot['end']),
              'expirationDate': _dateWireValue(slot['expirationDate']),
            };
          }).toList()
        : const <Map<String, dynamic>>[],
    'expirationDate': _dateWireValue(data['expirationDate']),
  });
}

String _dateWireValue(Object? value) {
  final date = switch (value) {
    DateTime() => value,
    String() => DateTime.tryParse(value),
    _ => null,
  };
  return date?.microsecondsSinceEpoch.toString() ?? value?.toString() ?? '';
}

bool _sameSlotIgnoringConfirmation(
  Map<String, dynamic> left,
  Map<String, dynamic> right,
) =>
    _dateWireValue(left['start']) == _dateWireValue(right['start']) &&
    _dateWireValue(left['end']) == _dateWireValue(right['end']) &&
    _dateWireValue(left['expirationDate']) ==
        _dateWireValue(right['expirationDate']);
