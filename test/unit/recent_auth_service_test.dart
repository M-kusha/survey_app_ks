import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reauthenticates before forcing a fresh token', () async {
    final events = <String>[];

    await performRecentPasswordAuthentication(
      email: 'owner@example.test',
      password: 'correct password',
      reauthenticate: (credential) async {
        events.add('reauth:${credential.providerId}');
      },
      forceTokenRefresh: () async => events.add('refresh'),
    );

    expect(events, ['reauth:password', 'refresh']);
  });

  test('does not refresh after an invalid password', () async {
    var refreshed = false;

    await expectLater(
      performRecentPasswordAuthentication(
        email: 'owner@example.test',
        password: 'wrong',
        reauthenticate: (_) async {
          throw FirebaseAuthException(code: 'invalid-credential');
        },
        forceTokenRefresh: () async => refreshed = true,
      ),
      throwsA(
        isA<RecentAuthenticationException>().having(
          (error) => error.failure,
          'failure',
          RecentAuthenticationFailure.invalidCredential,
        ),
      ),
    );
    expect(refreshed, isFalse);
  });

  test('maps a lost account and token-refresh failure safely', () async {
    await expectLater(
      performRecentPasswordAuthentication(
        email: '',
        password: 'password',
        reauthenticate: (_) async {},
        forceTokenRefresh: () async {},
      ),
      throwsA(
        isA<RecentAuthenticationException>().having(
          (error) => error.failure,
          'failure',
          RecentAuthenticationFailure.accountUnavailable,
        ),
      ),
    );

    await expectLater(
      performRecentPasswordAuthentication(
        email: 'owner@example.test',
        password: 'password',
        reauthenticate: (_) async {},
        forceTokenRefresh: () async => throw StateError('offline'),
      ),
      throwsA(
        isA<RecentAuthenticationException>().having(
          (error) => error.failure,
          'failure',
          RecentAuthenticationFailure.unavailable,
        ),
      ),
    );
  });
}
