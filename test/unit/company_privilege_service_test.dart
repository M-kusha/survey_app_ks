import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/membership/company_privilege_service.dart';
import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FunctionError extends FirebaseFunctionsException {
  _FunctionError(String code, String message)
    : super(code: code, message: message);
}

Matcher failsWith(CompanyCreationFailure failure) => throwsA(
  isA<CompanyCreationException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

void main() {
  test(
    'reauthenticates first and sends only the trimmed company name',
    () async {
      final events = <String>[];
      Map<String, dynamic>? request;
      final service = CompanyPrivilegeService(
        recentPasswordAuthenticator: (password) async {
          events.add('auth:$password');
        },
        createCompanyCallable: (payload) async {
          events.add('call');
          request = payload;
          return {
            'created': true,
            'companyId': 'company_1',
            'role': 'superadmin',
            'activityId': 'activity_1',
          };
        },
      );

      final receipt = await service.createCompany(
        companyName: '  Echo Works  ',
        password: 'current password',
      );

      expect(events, ['auth:current password', 'call']);
      expect(request, {'companyName': 'Echo Works'});
      expect(request, isNot(contains('password')));
      expect(request, isNot(contains('uid')));
      expect(request, isNot(contains('role')));
      expect(request, isNot(contains('companyId')));
      expect(receipt.companyId, 'company_1');
      expect(receipt.activityId, 'activity_1');
    },
  );

  test('rejects invalid names before authentication', () async {
    var authenticated = false;
    var called = false;
    final service = CompanyPrivilegeService(
      recentPasswordAuthenticator: (_) async => authenticated = true,
      createCompanyCallable: (_) async {
        called = true;
        return const {};
      },
    );

    await expectLater(
      service.createCompany(
        companyName: List.filled(121, 'x').join(),
        password: 'password',
      ),
      failsWith(CompanyCreationFailure.invalidName),
    );
    expect(authenticated, isFalse);
    expect(called, isFalse);
  });

  test('rejects incomplete or expanded success receipts', () async {
    for (final receipt in <Map<String, dynamic>>[
      {
        'created': true,
        'companyId': '',
        'role': 'superadmin',
        'activityId': 'activity_1',
      },
      {
        'created': true,
        'companyId': 'company_1',
        'role': 'admin',
        'activityId': 'activity_1',
      },
      {
        'created': true,
        'companyId': 'company_1',
        'role': 'superadmin',
        'activityId': 'activity_1',
        'unexpected': true,
      },
    ]) {
      final service = CompanyPrivilegeService(
        recentPasswordAuthenticator: (_) async {},
        createCompanyCallable: (_) async => receipt,
      );
      await expectLater(
        service.createCompany(companyName: 'Echo', password: 'password'),
        failsWith(CompanyCreationFailure.unavailable),
      );
    }
  });

  test('maps recent-auth failures without calling the backend', () async {
    for (final entry in {
      RecentAuthenticationFailure.invalidCredential:
          CompanyCreationFailure.invalidCredential,
      RecentAuthenticationFailure.accountUnavailable:
          CompanyCreationFailure.accountUnavailable,
      RecentAuthenticationFailure.unavailable:
          CompanyCreationFailure.unavailable,
    }.entries) {
      var called = false;
      final service = CompanyPrivilegeService(
        recentPasswordAuthenticator: (_) async {
          throw RecentAuthenticationException(entry.key);
        },
        createCompanyCallable: (_) async {
          called = true;
          return const {};
        },
      );
      await expectLater(
        service.createCompany(companyName: 'Echo', password: 'password'),
        failsWith(entry.value),
      );
      expect(called, isFalse);
    }
  });

  test(
    'maps callable failures to the safe company-creation taxonomy',
    () async {
      final cases = <FirebaseFunctionsException, CompanyCreationFailure>{
        _FunctionError('invalid-argument', 'company-name-invalid'):
            CompanyCreationFailure.invalidName,
        _FunctionError('invalid-argument', 'company-creation-request-invalid'):
            CompanyCreationFailure.invalidName,
        _FunctionError('already-exists', 'company-name-taken'):
            CompanyCreationFailure.nameTaken,
        _FunctionError(
          'failed-precondition',
          'company-creation-profile-invalid',
        ): CompanyCreationFailure.ineligible,
        _FunctionError('failed-precondition', 'onboarding-pending'):
            CompanyCreationFailure.ineligible,
        _FunctionError('failed-precondition', 'account-deletion-started'):
            CompanyCreationFailure.ineligible,
        _FunctionError(
          'failed-precondition',
          'company-membership-state-invalid',
        ): CompanyCreationFailure.ineligible,
        _FunctionError('failed-precondition', 'recent-login-required'):
            CompanyCreationFailure.recentLoginRequired,
        _FunctionError(
          'failed-precondition',
          'company-creation-account-unavailable',
        ): CompanyCreationFailure.accountUnavailable,
        _FunctionError('failed-precondition', 'email-not-verified'):
            CompanyCreationFailure.accountUnavailable,
        _FunctionError('unauthenticated', 'authentication-required'):
            CompanyCreationFailure.accountUnavailable,
        _FunctionError('internal', 'sensitive server detail'):
            CompanyCreationFailure.unavailable,
      };

      for (final entry in cases.entries) {
        final service = CompanyPrivilegeService(
          recentPasswordAuthenticator: (_) async {},
          createCompanyCallable: (_) async => throw entry.key,
        );
        await expectLater(
          service.createCompany(companyName: 'Echo', password: 'password'),
          failsWith(entry.value),
        );
      }
    },
  );
}
