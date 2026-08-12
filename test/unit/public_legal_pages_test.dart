import 'dart:convert';
import 'dart:io';

import 'package:echomeet/core/navigation/public_routes.dart';
import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

const _operator = 'Kushtrim Mulliqi';
const _contact = 'kushtrim.mulliqi@outlook.com';

const _requiredPrivacyKeys = [
  'privacy_title',
  'privacy_effective',
  'privacy_intro',
  'privacy_operator_title',
  'privacy_operator_body',
  'privacy_collect_title',
  'privacy_collect_body',
  'privacy_not_collected_title',
  'privacy_not_collected_body',
  'privacy_purpose_title',
  'privacy_purpose_body',
  'privacy_visibility_title',
  'privacy_visibility_body',
  'privacy_scoring_title',
  'privacy_scoring_body',
  'privacy_processors_title',
  'privacy_processors_body',
  'privacy_security_title',
  'privacy_security_body',
  'privacy_retention_title',
  'privacy_retention_body',
  'privacy_rights_title',
  'privacy_rights_body',
  'privacy_children_title',
  'privacy_children_body',
  'privacy_changes_title',
  'privacy_changes_body',
  'privacy_footer',
];

Map<String, Map<String, String>> _staticCopy() {
  const script = '''
const fs = require('node:fs');
const vm = require('node:vm');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync('web/legal/legal.js', 'utf8'), context);
process.stdout.write(JSON.stringify(context.EchoMeetLegalCopy));
''';
  final result = Process.runSync('node', ['-e', script]);
  expect(result.exitCode, 0, reason: result.stderr.toString());

  final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      entry.key: (entry.value as Map<String, dynamic>).cast<String, String>(),
  };
}

void main() {
  test('the privacy page is published, not a placeholder', () {
    final privacy = _read('web/privacy-policy/index.html');

    expect(privacy, contains('data-legal-page="privacy-policy"'));
    expect(privacy, contains('data-release-status="published"'));

    expect(privacy, isNot(contains('owner-input-required')));
    expect(privacy, isNot(contains('not an approved privacy policy')));

    for (final key in _requiredPrivacyKeys) {
      expect(privacy, contains('data-i18n="$key"'), reason: 'missing $key');
    }
  });

  test('the deletion page still refuses to confirm an account exists', () {
    final deletion = _read('web/account-deletion/index.html');

    expect(deletion, contains('data-legal-page="account-deletion"'));
    expect(deletion, contains('data-non-enumerating="true"'));
    expect(deletion, contains('does not reveal whether an account exists'));
  });

  test('the public pages ask for nothing and reveal no infrastructure', () {
    final publicSource =
        '${_read('web/privacy-policy/index.html')}\n'
        '${_read('web/account-deletion/index.html')}\n'
        '${_read('web/legal/legal.js')}';

    expect(publicSource.toLowerCase(), isNot(contains('<form')));
    expect(publicSource.toLowerCase(), isNot(contains('<input')));
    expect(publicSource, isNot(contains('[OWNER INPUT')));
  });

  test('Hosting refresh rewrites resolve both public entry routes', () {
    final config = jsonDecode(_read('firebase.json')) as Map<String, dynamic>;
    final hosting = config['hosting'] as Map<String, dynamic>;
    final rewrites = (hosting['rewrites'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final destinations = {
      for (final rewrite in rewrites)
        rewrite['source'] as String: rewrite['destination'] as String,
    };

    expect(hosting['public'], 'build/web');
    expect(destinations['/privacy-policy'], '/privacy-policy/index.html');
    expect(destinations['/privacy-policy/**'], '/privacy-policy/index.html');
    expect(destinations['/account-deletion'], '/account-deletion/index.html');
    expect(
      destinations['/account-deletion/**'],
      '/account-deletion/index.html',
    );
    expect(destinations['**'], '/index.html');
    expect(
      rewrites.last['source'],
      '**',
      reason: 'SPA fallback must stay last',
    );

    final apache = _read('web/.htaccess');
    expect(apache, contains('RewriteCond %{REQUEST_FILENAME} -d'));
    expect(apache, contains('RewriteRule ^ index.html [L]'));
  });

  test('static legal copy exposes the same complete en/de/sq key set', () {
    final copy = _staticCopy();
    expect(copy.keys.toSet(), {'en', 'de', 'sq'});

    final englishKeys = copy['en']!.keys.toSet();
    for (final locale in const ['en', 'de', 'sq']) {
      final values = copy[locale]!;
      expect(values.keys.toSet(), englishKeys, reason: '$locale key mismatch');
      for (final entry in values.entries) {
        expect(entry.value.trim(), isNotEmpty);
        expect(entry.value, isNot(entry.key));
      }
    }

    expect(
      copy['en']!['deletion_access_body'],
      contains('does not reveal whether an account exists'),
    );
  });

  test('every locale of the policy names the controller and the contact', () {
    final copy = _staticCopy();

    for (final locale in const ['en', 'de', 'sq']) {
      final values = copy[locale]!;
      for (final key in _requiredPrivacyKeys) {
        expect(values, contains(key), reason: '$locale is missing $key');
      }
      expect(values['privacy_operator_body'], contains(_operator));
      expect(values['privacy_operator_body'], contains(_contact));
      expect(values['privacy_rights_body'], contains(_contact));
      expect(values['privacy_footer'], contains(_contact));
      expect(values['privacy_effective'], contains('2026'));
    }
  });

  test('the in-app summary names the same controller in every locale', () {
    for (final locale in const ['en', 'de', 'sq']) {
      final copy =
          jsonDecode(_read('assets/translations/$locale.json'))
              as Map<String, dynamic>;

      for (final key in const [
        'privacy_policy_effective',
        'privacy_policy_summary',
        'privacy_policy_operator_body',
        'privacy_policy_data_body',
        'privacy_policy_visibility_body',
        'privacy_policy_no_tracking_body',
        'privacy_policy_rights_body',
        'privacy_policy_full_link',
      ]) {
        final value = copy[key];
        expect(value, isA<String>(), reason: '$locale is missing $key');
        expect((value as String).trim(), isNotEmpty);
      }

      expect(copy['privacy_policy_operator_body'], contains(_operator));
      expect(copy['privacy_policy_operator_body'], contains(_contact));
      expect(copy['privacy_policy_rights_body'], contains(_contact));

      for (final stale in const [
        'privacy_policy_release_status_title',
        'privacy_policy_release_status_body',
        'privacy_policy_source_title',
        'privacy_policy_source_body',
        'privacy_policy_owner_input_title',
        'privacy_policy_owner_input_body',
      ]) {
        expect(
          copy,
          isNot(contains(stale)),
          reason: '$locale still has $stale',
        );
      }
    }
  });

  test('the app and the notification link agree on the origin', () {
    final messaging = _read('functions/src/messaging.ts');
    final origin = PublicRoutePaths.canonicalOrigin;

    expect(
      messaging,
      contains(origin),
      reason: 'messaging.ts does not link to $origin',
    );
    expect(origin, startsWith('https://'));
    expect(origin, isNot(endsWith('/')));
    expect(
      PublicRoutePaths.privacyPolicyUrl,
      '$origin${PublicRoutePaths.privacyPolicy}',
    );
  });
}
