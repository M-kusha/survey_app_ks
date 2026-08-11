import 'package:echomeet/appointments/firebase/appointment_services.dart';
import 'package:echomeet/survey_pages/utilities/firebase_survey_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends the exact trusted survey deletion request', () async {
    Map<String, dynamic>? request;
    final service = FirebaseSurveyService(
      contentDeletionCallable: (payload) async {
        request = payload;
        return {
          'entityType': 'survey',
          'entityId': 'survey_1',
          'deleted': true,
        };
      },
    );

    await service.deleteSurvey('survey_1');
    expect(request, {'entityType': 'survey', 'entityId': 'survey_1'});
  });

  test('sends the exact trusted appointment deletion request', () async {
    Map<String, dynamic>? request;
    final service = AppointmentService(
      definitionCallable: (_) async => const <String, dynamic>{},
      contentDeletionCallable: (payload) async {
        request = payload;
        return {
          'entityType': 'appointment',
          'entityId': 'meeting_1',
          'deleted': true,
        };
      },
    );

    await service.deleteAppointment('meeting_1');
    expect(request, {'entityType': 'appointment', 'entityId': 'meeting_1'});
  });

  test('rejects mismatched server receipts', () async {
    final service = FirebaseSurveyService(
      contentDeletionCallable: (_) async => {
        'entityType': 'survey',
        'entityId': 'different',
        'deleted': true,
      },
    );

    await expectLater(service.deleteSurvey('survey_1'), throwsFormatException);
  });
}
