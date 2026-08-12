import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings exposes the Auth-first email change page', () {
    final settings = File('lib/settings/settings.dart').readAsStringSync();
    final page = File('lib/settings/change_email.dart').readAsStringSync();
    final service = File(
      'lib/core/security/email_change_service.dart',
    ).readAsStringSync();

    expect(settings, contains('ChangeEmailPage'));
    expect(settings, contains("title: 'change_email'.tr()"));
    expect(page, contains('syncVerifiedEmail('));
    expect(page, contains('expectedEmail: expectedEmail'));
    expect(page, contains('UserDataProvider>().loadCurrentUser()'));
    expect(service, contains('verifyBeforeUpdateEmail(newEmail)'));
    expect(service, isNot(contains('.updateEmail(')));
  });

  test('the verified-email sync only ever runs on a freshly minted token', () {
    final source = File(
      'lib/register/deferred_onboarding.dart',
    ).readAsStringSync();

    final reload = source.indexOf('await user.reload()');
    final token = source.indexOf('await refreshed!.getIdToken(true)');
    final sync = source.indexOf(
      'await _emailChangeService.syncAfterAuthenticationRefresh()',
    );

    expect(reload, greaterThanOrEqualTo(0));
    expect(token, greaterThan(reload));
    expect(sync, greaterThan(token));
    expect(
      source.substring(sync, sync + 200),
      contains('OnboardingFailure.retryable'),
      reason: 'a failed sync must still stop sign-in with a retryable failure',
    );
  });

  test('a returning member is not held behind the onboarding round trips', () {
    final source = File(
      'lib/register/deferred_onboarding.dart',
    ).readAsStringSync();

    final read = source.indexOf('await _readIntent(user.uid)');
    final reload = source.indexOf('await user.reload()');

    expect(
      read,
      allOf(greaterThanOrEqualTo(0), lessThan(reload)),
      reason:
          'the pending-onboarding read has to come first, or every sign-in '
          'waits on a reload, a forced token refresh and an email-sync '
          'callable it does not need',
    );
    expect(
      source.substring(read, reload),
      contains('unawaited(_refreshVerifiedSession())'),
    );
  });

  for (final locale in const ['en', 'de', 'sq']) {
    test('email change has complete safe copy in $locale', () {
      final copy =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final key in const {
        'change_email',
        'change_email_hint',
        'change_email_old_address_notice',
        'change_email_request_sent',
        'change_email_send_link',
        'email_change_account_unavailable',
        'email_change_already_in_use',
        'email_change_already_synced',
        'email_change_invalid',
        'email_change_not_yet_verified',
        'email_change_recent_login',
        'email_change_same',
        'email_change_synced',
        'email_change_unavailable',
        'email_change_verified_action',
        'new_email',
      }) {
        expect(copy[key], isA<String>(), reason: '$locale:$key');
        expect((copy[key] as String).trim(), isNotEmpty);
        expect(copy[key], isNot(key));
      }
    });
  }
}
