import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every client appointment list query binds tenant and v2 schema', () {
    for (final path in [
      'lib/appointments/firebase/appointment_provider.dart',
      'lib/core/membership/company_admin_service.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final appointmentQuery = source.indexOf(".collection('appointments')");
      expect(appointmentQuery, isNonNegative, reason: path);
      final queryWindow = source.substring(
        appointmentQuery,
        (appointmentQuery + 350).clamp(0, source.length),
      );
      expect(
        queryWindow,
        contains(".where('companyId', isEqualTo: companyId)"),
        reason: path,
      );
      expect(
        queryWindow,
        contains(
          ".where('schemaVersion', isEqualTo: Appointment.schemaVersion)",
        ),
        reason: path,
      );
    }
  });
}
