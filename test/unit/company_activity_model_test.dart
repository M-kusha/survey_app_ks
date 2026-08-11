import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:echomeet/core/membership/company_activity_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> validEvent() => {
    'schemaVersion': 1,
    'companyId': 'company_1',
    'action': 'member.role_changed',
    'actorUid': 'owner_1',
    'targetUid': 'member_1',
    'occurredAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
    'before': {'role': 'user'},
    'after': {'role': 'moderator'},
  };

  test('decodes the exact non-PII activity contract', () {
    final activity = CompanyActivity.fromData(
      id: 'activity_1',
      data: validEvent(),
    );

    expect(activity, isNotNull);
    expect(activity!.action, 'member.role_changed');
    expect(activity.actorUid, 'owner_1');
    expect(activity.targetUid, 'member_1');
    expect(activity.before, {'role': 'user'});
    expect(activity.after, {'role': 'moderator'});
    expect(CompanyActivityService.pageSize, 25);
  });

  test('fails closed on unknown top-level or change fields', () {
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {...validEvent(), 'email': 'person@example.test'},
      ),
      isNull,
    );
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {
          ...validEvent(),
          'after': {'role': 'moderator', 'fullName': 'A Person'},
        },
      ),
      isNull,
    );
  });

  test('fails closed on malformed target and change values', () {
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {...validEvent(), 'targetUid': 42},
      ),
      isNull,
    );
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {
          ...validEvent(),
          'after': {'role': 'owner'},
        },
      ),
      isNull,
    );
  });
}
