import 'package:echomeet/survey_pages/utilities/survey_data_provider.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('live directory identity overrides snapshots and fails neutral', () {
    final participant = Participant(
      userId: 'retained-uid',
      name: 'Historical spoof must never render',
      surveyAnswers: const {},
      score: 0,
    );

    applyParticipantDirectorySnapshot(
      [participant],
      const {'retained-uid': 'Current canonical name'},
    );
    expect(
      participant.auditLabel(),
      'Current canonical name · UID retained-uid',
    );

    applyParticipantDirectorySnapshot([participant], const {});
    expect(participant.auditLabel(), 'Unknown · UID retained-uid');

    applyParticipantDirectorySnapshot(
      [participant],
      const {'retained-uid': 'Current canonical name'},
    );
    applyParticipantDirectoryError([participant]);
    expect(participant.auditLabel(), 'Unknown · UID retained-uid');
  });
}
