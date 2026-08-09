import 'package:echomeet/core/profile/profile_image_revision.dart';
import 'package:echomeet/survey_pages/utilities/survey_questionary_class.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('avatar revisions accept only bounded Firestore integers', () {
    expect(readProfileImageRevision(7), 7);
    expect(readProfileImageRevision(null), 0);
    expect(readProfileImageRevision(-1), 0);
    expect(readProfileImageRevision(1.5), 0);
    expect(readProfileImageRevision(maximumProfileImageRevision + 1), 0);
  });

  test('participant snapshots retain the avatar revision', () {
    final participant = Participant.fromFirestore({
      'userId': 'alice',
      'name': 'Alice',
      'answers': <String, List<dynamic>>{},
      'score': 0,
      'profileImageRevision': 12,
    });

    expect(participant.profileImageRevision, 12);
    expect(participant.toFirestoreMap()['profileImageRevision'], 12);
  });
}
