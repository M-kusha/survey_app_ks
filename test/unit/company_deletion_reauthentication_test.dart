import 'package:echomeet/core/membership/company_admin_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reauthenticates before forcing a fresh company-deletion token',
    () async {
      final events = <String>[];

      await reauthenticateForCompanyDeletion(
        email: 'owner@example.test',
        password: 'correct horse battery staple',
        reauthenticate: (credential) async {
          events.add('reauth:${credential.providerId}');
        },
        forceRefresh: () async => events.add('refresh'),
      );

      expect(events, ['reauth:password', 'refresh']);
    },
  );

  test('maps credential rejection and never refreshes that session', () async {
    var refreshed = false;

    await expectLater(
      reauthenticateForCompanyDeletion(
        email: 'owner@example.test',
        password: 'wrong',
        reauthenticate: (_) async {
          throw FirebaseAuthException(code: 'wrong-password');
        },
        forceRefresh: () async => refreshed = true,
      ),
      throwsA(isA<CompanyReauthenticationFailure>()),
    );
    expect(refreshed, isFalse);
  });

  test('does not mislabel token refresh failures as bad credentials', () async {
    final refreshFailure = StateError('offline');

    await expectLater(
      reauthenticateForCompanyDeletion(
        email: 'owner@example.test',
        password: 'correct',
        reauthenticate: (_) async {},
        forceRefresh: () async => throw refreshFailure,
      ),
      throwsA(same(refreshFailure)),
    );
  });
}
