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

  Map<String, dynamic> contentEvent(
    String action, {
    required String type,
    Map<String, dynamic>? after,
  }) {
    final result = <String, dynamic>{
      'schemaVersion': 1,
      'companyId': 'company_1',
      'action': action,
      'actorUid': 'owner_1',
      'occurredAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
      'entity': {
        'type': type,
        'id': 'content_1',
        'title': 'Quarterly planning',
      },
    };
    if (after != null) result['after'] = after;
    return result;
  }

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

  test('decodes every exact content action shape', () {
    for (final action in const ['survey.created', 'survey.deleted']) {
      for (final type in const ['survey', 'test']) {
        final activity = CompanyActivity.fromData(
          id: '$action-$type',
          data: contentEvent(action, type: type),
        );
        expect(activity, isNotNull, reason: '$action $type');
        expect(activity!.entity!.type, type);
        expect(activity.entity!.title, 'Quarterly planning');
      }
    }

    for (final action in const [
      'appointment.created',
      'appointment.updated',
      'appointment.deleted',
    ]) {
      expect(
        CompanyActivity.fromData(
          id: action,
          data: contentEvent(action, type: 'appointment'),
        ),
        isNotNull,
        reason: action,
      );
    }

    final confirmedAt = Timestamp.fromDate(DateTime.utc(2026, 8, 14, 10));
    final confirmation = CompanyActivity.fromData(
      id: 'appointment-confirmed-content_1',
      data: contentEvent(
        'appointment.slot_confirmed',
        type: 'appointment',
        after: {'confirmedStartAt': confirmedAt},
      ),
    );
    expect(confirmation, isNotNull);
    expect(confirmation!.after, {'confirmedStartAt': confirmedAt});
  });

  test('decodes the exact administrative action shapes', () {
    final occurredAt = Timestamp.fromDate(DateTime.utc(2026, 8, 12));
    final scheduledFor = Timestamp.fromDate(DateTime.utc(2026, 8, 19));
    Map<String, dynamic> event(
      String action, {
      String? targetUid,
      Map<String, dynamic>? before,
      Map<String, dynamic>? after,
    }) {
      final result = <String, dynamic>{
        'schemaVersion': 1,
        'companyId': 'company_1',
        'action': action,
        'actorUid': 'owner_1',
        'occurredAt': occurredAt,
      };
      if (targetUid != null) result['targetUid'] = targetUid;
      if (before != null) result['before'] = before;
      if (after != null) result['after'] = after;
      return result;
    }

    final events = [
      event(
        'member.approved',
        targetUid: 'member_1',
        before: {'membership': 'pending'},
        after: {'membership': 'active'},
      ),
      event(
        'member.banned',
        targetUid: 'member_1',
        before: {'membership': 'active'},
        after: {'membership': 'pending'},
      ),
      event(
        'member.unbanned',
        targetUid: 'member_1',
        before: {'membership': 'pending'},
        after: {'membership': 'active'},
      ),
      event('member.unbanned', targetUid: 'former_member_1'),
      event(
        'member.removed',
        targetUid: 'member_1',
        before: {'role': 'moderator', 'membership': 'active'},
        after: {'role': 'user', 'membership': 'active'},
      ),
      event('member.company_data_erased', targetUid: 'former_member_1'),
      event(
        'company.join_policy_changed',
        before: {'joinPolicy': 'open'},
        after: {'joinPolicy': 'approval'},
      ),
      event(
        'company.deletion_scheduled',
        after: {'deletionScheduledFor': scheduledFor},
      ),
      event(
        'company.deletion_cancelled',
        before: {'deletionScheduledFor': scheduledFor},
      ),
      event('company.created', after: {'ownerUid': 'owner_1'}),
      event(
        'company.ownership_transferred',
        targetUid: 'member_1',
        before: {'ownerUid': 'owner_1'},
        after: {'ownerUid': 'member_1'},
      ),
      event('account.email_changed'),
    ];

    for (final (index, data) in events.indexed) {
      expect(
        CompanyActivity.fromData(id: 'activity_$index', data: data),
        isNotNull,
        reason: '${data['action']}',
      );
    }
  });

  test('fails closed when an action and its subject or state disagree', () {
    final invalidEvents = <Map<String, dynamic>>[
      contentEvent('survey.created', type: 'appointment'),
      contentEvent('appointment.created', type: 'survey'),
      {
        ...contentEvent('survey.deleted', type: 'survey'),
        'targetUid': 'user_1',
      },
      contentEvent('appointment.slot_confirmed', type: 'appointment'),
      {
        ...contentEvent('appointment.slot_confirmed', type: 'appointment'),
        'after': {'confirmedStartAt': 'tomorrow'},
      },
      {
        'schemaVersion': 1,
        'companyId': 'company_1',
        'action': 'account.email_changed',
        'actorUid': 'owner_1',
        'occurredAt': Timestamp.fromDate(DateTime.utc(2026, 8, 12)),
        'entity': {'type': 'survey', 'id': 'survey_1', 'title': 'Injected'},
      },
      {...validEvent(), 'targetUid': null},
      {...validEvent(), 'targetUid': 'owner_1'},
    ];

    for (final event in invalidEvents) {
      expect(
        CompanyActivity.fromData(id: 'activity_1', data: event),
        isNull,
        reason: '${event['action']}',
      );
    }
  });

  test('fails closed on non-canonical IDs and entity fields', () {
    final base = contentEvent('survey.created', type: 'survey');
    expect(CompanyActivity.fromData(id: ' activity_1', data: base), isNull);
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {
          ...base,
          'entity': {'type': 'survey', 'id': ' survey_1', 'title': 'Title'},
        },
      ),
      isNull,
    );
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {
          ...base,
          'entity': {
            'type': 'survey',
            'id': 'survey_1',
            'title': List.filled(121, 'x').join(),
          },
        },
      ),
      isNull,
    );
    expect(
      CompanyActivity.fromData(
        id: 'activity_1',
        data: {
          ...base,
          'entity': {
            'type': 'survey',
            'id': 'survey_1',
            'title': 'Title',
            'url': 'https://example.test',
          },
        },
      ),
      isNull,
    );
  });

  test('normalizes display names and ignores unsafe values', () {
    expect(safeActivityMemberName('  Ada\nLovelace  '), 'Ada Lovelace');
    expect(safeActivityMemberName('A\u202eecilA'), 'A ecilA');
    expect(safeActivityMemberName('   '), isNull);
    expect(safeActivityMemberName(42), isNull);
    expect(safeActivityMemberName(List.filled(161, 'x').join()), isNull);
  });
}
