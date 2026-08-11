import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _read(String path) => File(path).readAsStringSync();

void main() {
  test('signed-out static privacy and deletion entry pages are present', () {
    final privacy = _read('web/privacy-policy/index.html');
    final deletion = _read('web/account-deletion/index.html');

    expect(privacy, contains('data-legal-page="privacy-policy"'));
    expect(privacy, contains('data-release-status="owner-input-required"'));
    expect(privacy, contains('not an approved privacy policy'));
    expect(privacy, isNot(contains('data-release-status="approved"')));

    expect(deletion, contains('data-legal-page="account-deletion"'));
    expect(deletion, contains('data-non-enumerating="true"'));
    expect(deletion, contains('does not reveal whether an account exists'));

    final publicSource = '$privacy\n$deletion\n${_read('web/legal/legal.js')}';
    expect(publicSource.toLowerCase(), isNot(contains('<form')));
    expect(publicSource.toLowerCase(), isNot(contains('<input')));
    expect(publicSource, isNot(contains('Firebase')));
    expect(publicSource, isNot(contains('AppCheck')));
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
    final script = '''
const fs = require('node:fs');
const vm = require('node:vm');
const context = {};
vm.createContext(context);
vm.runInContext(fs.readFileSync('web/legal/legal.js', 'utf8'), context);
process.stdout.write(JSON.stringify(context.EchoMeetLegalCopy));
''';
    final result = Process.runSync('node', ['-e', script]);

    expect(result.exitCode, 0, reason: result.stderr.toString());
    final copy = jsonDecode(result.stdout as String) as Map<String, dynamic>;
    expect(copy.keys.toSet(), {'en', 'de', 'sq'});

    final english = (copy['en'] as Map<String, dynamic>);
    final englishKeys = english.keys.toSet();
    for (final locale in const ['en', 'de', 'sq']) {
      final values = copy[locale] as Map<String, dynamic>;
      expect(values.keys.toSet(), englishKeys, reason: '$locale key mismatch');
      for (final entry in values.entries) {
        expect(entry.value, isA<String>());
        expect((entry.value as String).trim(), isNotEmpty);
        expect(entry.value, isNot(entry.key));
      }
    }

    expect(
      english['deletion_access_body'],
      contains('does not reveal whether an account exists'),
    );
    expect(
      english['privacy_intro'],
      contains('not an approved privacy policy'),
    );
  });
}
