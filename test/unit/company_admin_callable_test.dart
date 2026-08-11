import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sends only the trusted company administration payloads', () async {
    final requests = <Map<String, dynamic>>[];
    final service = CompanyAdminService(
      administerCompanyCallable: (payload) async {
        requests.add(payload);
        final action = payload['action'] as String;
        return {
          'completed': true,
          'action': action,
          'companyId': 'company_1',
          'activityId': 'activity_${requests.length}',
          if (payload['targetUid'] case final String targetUid)
            'targetUid': targetUid,
          if (action == 'approveMember' || action == 'banMember')
            'membership': action == 'approveMember' ? 'active' : 'pending',
          if (action == 'changeMemberRole') 'role': payload['role'],
          if (action == 'removeMember' || action == 'eraseMemberCompanyData')
            'released': true,
          if (action == 'setJoinPolicy') 'joinPolicy': payload['joinPolicy'],
          if (action == 'cancelDeletion') 'cancelled': true,
        };
      },
    );

    await service.approve('member_1');
    await service.changeRole('member_2', 'moderator');
    await service.ban('member_3');
    await service.unban('member_4');
    await service.remove('member_5');
    await service.erase('member_6');
    await service.setJoinPolicy(open: false);
    await service.cancelDeletion();

    expect(requests, [
      {'action': 'approveMember', 'targetUid': 'member_1'},
      {
        'action': 'changeMemberRole',
        'targetUid': 'member_2',
        'role': 'moderator',
      },
      {'action': 'banMember', 'targetUid': 'member_3'},
      {'action': 'unbanMember', 'targetUid': 'member_4'},
      {'action': 'removeMember', 'targetUid': 'member_5'},
      {'action': 'eraseMemberCompanyData', 'targetUid': 'member_6'},
      {'action': 'setJoinPolicy', 'joinPolicy': 'approval'},
      {'action': 'cancelDeletion'},
    ]);
  });

  test('rejects an incomplete administration receipt', () async {
    final service = CompanyAdminService(
      administerCompanyCallable: (payload) async => {
        'completed': true,
        'action': payload['action'],
        'companyId': 'company_1',
      },
    );

    await expectLater(service.approve('member_1'), throwsFormatException);
  });

  test('rejects unsupported roles before making a request', () async {
    var called = false;
    final service = CompanyAdminService(
      administerCompanyCallable: (_) async {
        called = true;
        return const {};
      },
    );

    await expectLater(
      service.changeRole('member_1', 'superadmin'),
      throwsArgumentError,
    );
    expect(called, isFalse);
  });
}
