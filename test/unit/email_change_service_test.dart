import 'package:cloud_functions/cloud_functions.dart';
import 'package:echomeet/core/security/email_change_service.dart';
import 'package:echomeet/core/security/recent_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

class _FunctionError extends FirebaseFunctionsException {
  _FunctionError(String code, String message)
    : super(code: code, message: message);
}

Matcher failsWith(EmailChangeFailure failure) => throwsA(
  isA<EmailChangeException>().having(
    (error) => error.failure,
    'failure',
    failure,
  ),
);

void main() {
  test(
    'request normalizes locally and uses Auth without calling Functions',
    () async {
      final events = <String>[];
      String? expectedCurrentEmail;
      String? requestedEmail;
      var functionCalled = false;
      final service = EmailChangeService(
        currentAddressReader: () => 'Current@Example.Test',
        recentPasswordAuthenticator: (password) async {
          events.add('auth:$password');
        },
        verificationRequester: (currentEmail, newEmail) async {
          events.add('verify');
          expectedCurrentEmail = currentEmail;
          requestedEmail = newEmail;
        },
        verifiedEmailPreparer: () async => 'new@example.test',
        verifiedEmailReader: () async => 'new@example.test',
        syncVerifiedEmailCallable: (_) async {
          functionCalled = true;
          return {'synced': true, 'changed': true};
        },
      );

      final receipt = await service.requestChange(
        newEmail: '  New@Example.Test  ',
        password: 'current password',
      );

      expect(events, ['auth:current password', 'verify']);
      expect(expectedCurrentEmail, 'current@example.test');
      expect(requestedEmail, 'new@example.test');
      expect(receipt.newEmail, 'new@example.test');
      expect(functionCalled, isFalse);
    },
  );

  test('invalid and unchanged addresses stop before authentication', () async {
    var authenticated = false;
    final service = EmailChangeService(
      currentAddressReader: () => 'person@example.test',
      recentPasswordAuthenticator: (_) async => authenticated = true,
      verificationRequester: (_, _) async {},
      verifiedEmailPreparer: () async => 'person@example.test',
      verifiedEmailReader: () async => 'person@example.test',
      syncVerifiedEmailCallable: (_) async => {
        'synced': true,
        'changed': false,
      },
    );

    await expectLater(
      service.requestChange(newEmail: 'not-an-email', password: 'password'),
      failsWith(EmailChangeFailure.invalidEmail),
    );
    await expectLater(
      service.requestChange(
        newEmail: ' PERSON@example.test ',
        password: 'password',
      ),
      failsWith(EmailChangeFailure.unchangedEmail),
    );
    expect(authenticated, isFalse);
  });

  test('request maps recent-auth and Firebase Auth failures safely', () async {
    for (final entry in {
      RecentAuthenticationFailure.invalidCredential:
          EmailChangeFailure.invalidCredential,
      RecentAuthenticationFailure.accountUnavailable:
          EmailChangeFailure.accountUnavailable,
      RecentAuthenticationFailure.unavailable: EmailChangeFailure.unavailable,
    }.entries) {
      final service = EmailChangeService(
        currentAddressReader: () => 'old@example.test',
        recentPasswordAuthenticator: (_) async {
          throw RecentAuthenticationException(entry.key);
        },
        verificationRequester: (_, _) async {},
      );
      await expectLater(
        service.requestChange(
          newEmail: 'new@example.test',
          password: 'password',
        ),
        failsWith(entry.value),
      );
    }

    for (final entry in {
      'invalid-email': EmailChangeFailure.invalidEmail,
      'email-already-in-use': EmailChangeFailure.emailAlreadyInUse,
      'requires-recent-login': EmailChangeFailure.recentLoginRequired,
      'user-token-expired': EmailChangeFailure.accountUnavailable,
      'too-many-requests': EmailChangeFailure.unavailable,
    }.entries) {
      final service = EmailChangeService(
        currentAddressReader: () => 'old@example.test',
        recentPasswordAuthenticator: (_) async {},
        verificationRequester: (_, _) async {
          throw FirebaseAuthException(code: entry.key);
        },
      );
      await expectLater(
        service.requestChange(
          newEmail: 'new@example.test',
          password: 'password',
        ),
        failsWith(entry.value),
      );
    }
  });

  test('sync prepares Auth first and sends an exact empty payload', () async {
    final events = <String>[];
    Map<String, dynamic>? payload;
    final service = EmailChangeService(
      currentAddressReader: () => 'old@example.test',
      recentPasswordAuthenticator: (_) async {},
      verificationRequester: (_, _) async {},
      verifiedEmailPreparer: () async {
        events.add('reload-verify-token');
        return ' NEW@EXAMPLE.TEST ';
      },
      verifiedEmailReader: () async => 'new@example.test',
      syncVerifiedEmailCallable: (request) async {
        events.add('call');
        payload = request;
        return {'synced': true, 'changed': true};
      },
    );

    final receipt = await service.syncVerifiedEmail(
      expectedEmail: 'new@example.test',
    );

    expect(events, ['reload-verify-token', 'call']);
    expect(payload, isEmpty);
    expect(payload, isNot(contains('email')));
    expect(payload, isNot(contains('password')));
    expect(receipt.changed, isTrue);
  });

  test(
    'same-session sync waits for Auth to expose the requested address',
    () async {
      var functionCalled = false;
      final service = EmailChangeService(
        verifiedEmailPreparer: () async => 'old@example.test',
        syncVerifiedEmailCallable: (_) async {
          functionCalled = true;
          return {'synced': true, 'changed': false};
        },
      );

      await expectLater(
        service.syncVerifiedEmail(expectedEmail: 'new@example.test'),
        failsWith(EmailChangeFailure.verificationPending),
      );
      expect(functionCalled, isFalse);
    },
  );

  test(
    'startup sync accepts a trusted no-op without an expected address',
    () async {
      final service = EmailChangeService(
        verifiedEmailPreparer: () async => 'current@example.test',
        syncVerifiedEmailCallable: (payload) async => {
          'synced': true,
          'changed': false,
        },
      );

      final receipt = await service.syncVerifiedEmail();
      expect(receipt.changed, isFalse);
    },
  );

  test(
    'prepared gate sync skips reload but still sends exact empty data',
    () async {
      var prepared = false;
      var read = false;
      Map<String, dynamic>? payload;
      final service = EmailChangeService(
        verifiedEmailPreparer: () async {
          prepared = true;
          return 'person@example.test';
        },
        verifiedEmailReader: () async {
          read = true;
          return 'person@example.test';
        },
        syncVerifiedEmailCallable: (request) async {
          payload = request;
          return {'synced': true, 'changed': false};
        },
      );

      await service.syncAfterAuthenticationRefresh();
      expect(prepared, isFalse);
      expect(read, isTrue);
      expect(payload, isEmpty);
    },
  );

  test('rejects malformed or expanded sync receipts', () async {
    for (final response in <Map<String, dynamic>>[
      {'synced': false, 'changed': true},
      {'synced': true, 'changed': 'yes'},
      {'synced': true, 'changed': true, 'email': 'private@example.test'},
    ]) {
      final service = EmailChangeService(
        verifiedEmailPreparer: () async => 'person@example.test',
        syncVerifiedEmailCallable: (_) async => response,
      );
      await expectLater(
        service.syncVerifiedEmail(),
        failsWith(EmailChangeFailure.unavailable),
      );
    }
  });

  test('maps exact backend account and profile failures', () async {
    for (final message in const {
      'email-sync-account-unavailable',
      'email-sync-profile-missing',
    }) {
      final service = EmailChangeService(
        verifiedEmailPreparer: () async => 'person@example.test',
        syncVerifiedEmailCallable: (_) async {
          throw _FunctionError('failed-precondition', message);
        },
      );
      await expectLater(
        service.syncVerifiedEmail(),
        failsWith(EmailChangeFailure.accountUnavailable),
        reason: message,
      );
    }

    final deleting = EmailChangeService(
      verifiedEmailPreparer: () async => 'person@example.test',
      syncVerifiedEmailCallable: (_) async {
        throw _FunctionError('failed-precondition', 'account-deletion-started');
      },
    );
    await expectLater(
      deleting.syncVerifiedEmail(),
      failsWith(EmailChangeFailure.unavailable),
    );
  });
}
