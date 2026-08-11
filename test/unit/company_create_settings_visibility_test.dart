import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings exposes creation only through the no-company state', () {
    final source = File('lib/settings/settings.dart').readAsStringSync();

    expect(source, contains('membership?.state == MembershipState.noCompany'));
    expect(source, contains('if (canCreateCompany)'));
    expect(source, contains('CreateCompanyPage'));
    expect(source, contains('CompanyBrowserPage'));
    expect(source, isNot(contains('accountType')));

    final form = File('lib/settings/create_company.dart').readAsStringSync();
    expect(form, contains('CompanyPrivilegeService.maxCompanyNameLength'));
  });

  for (final locale in const ['en', 'de', 'sq']) {
    test('company creation has complete safe copy in $locale', () {
      final copy =
          jsonDecode(
                File('assets/translations/$locale.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      for (final key in const {
        'create_company',
        'create_company_account_unavailable',
        'create_company_hint',
        'create_company_ineligible',
        'create_company_owner_notice',
        'create_company_recent_login',
        'create_company_settings_hint',
        'create_company_success',
        'create_company_unavailable',
        'current_password',
        'invalid_current_password',
      }) {
        expect(copy[key], isA<String>(), reason: '$locale:$key');
        expect((copy[key] as String).trim(), isNotEmpty);
        expect(copy[key], isNot(key));
      }
    });
  }
}
