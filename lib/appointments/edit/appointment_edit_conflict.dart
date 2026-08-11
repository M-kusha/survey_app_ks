import 'package:cloud_functions/cloud_functions.dart';

class AppointmentEditConflict implements Exception {
  const AppointmentEditConflict();
}

class AppointmentEditMissing implements Exception {
  const AppointmentEditMissing();
}

class AppointmentVotedSlotRemovalBlocked implements Exception {
  AppointmentVotedSlotRemovalBlocked(Iterable<String> blockedSlotIds)
    : blockedSlotIds = List.unmodifiable(blockedSlotIds);

  final List<String> blockedSlotIds;
}

AppointmentVotedSlotRemovalBlocked? parseVotedSlotRemovalError(
  FirebaseFunctionsException error,
) {
  if (error.code != 'failed-precondition' ||
      error.message != 'appointment-voted-slot-removal-blocked') {
    return null;
  }
  final details = error.details;
  if (details is! Map ||
      details.length != 1 ||
      !details.containsKey('blockedSlotIds')) {
    return null;
  }
  final values = details['blockedSlotIds'];
  if (values is! List || values.isEmpty || values.length > 100) return null;
  final slotIds = <String>[];
  final identifier = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
  for (final value in values) {
    if (value is! String ||
        !identifier.hasMatch(value) ||
        (slotIds.isNotEmpty && slotIds.last.compareTo(value) >= 0)) {
      return null;
    }
    slotIds.add(value);
  }
  return AppointmentVotedSlotRemovalBlocked(slotIds);
}
