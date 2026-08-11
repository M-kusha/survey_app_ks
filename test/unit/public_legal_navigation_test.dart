import 'dart:convert';
import 'dart:io';

import 'package:echomeet/utilities/routes.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _loadCopy(String locale) {
  final source = File('assets/translations/$locale.json').readAsStringSync();
  return jsonDecode(source) as Map<String, dynamic>;
}

void main() {
  test('the application registers both public legal routes', () {
    final routes = AppRoutes.routes();

    expect(routes, contains('/privacy-policy'));
    expect(routes, contains('/account-deletion'));
  });

  test('the signed-out login links use the intended public routes', () {
    final source = File('lib/login/login.dart').readAsStringSync();
    final widgetStart = source.indexOf('class PublicLegalLinks');

    expect(widgetStart, greaterThanOrEqualTo(0));
    final widgetSource = source.substring(widgetStart);
    expect(source, contains('const PublicLegalLinks()'));
    expect(widgetSource, contains('PublicRoutePaths.privacyPolicy'));
    expect(widgetSource, contains('PublicRoutePaths.accountDeletion'));
  });

  for (final locale in const ['en', 'de', 'sq']) {
    test('legal link copy is present and localized in $locale', () {
      final copy = _loadCopy(locale);

      for (final key in const [
        'privacy_policy_link',
        'account_deletion_info_link',
      ]) {
        final value = copy[key];
        expect(value, isA<String>(), reason: '$locale is missing $key');
        expect((value as String).trim(), isNotEmpty);
        expect(value, isNot(key), reason: '$locale falls back to a raw key');
      }
    });
  }
}
