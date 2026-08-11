import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';

function option(name) {
  const index = process.argv.indexOf(name);
  return index < 0 ? undefined : process.argv[index + 1];
}

const sourceRoot = path.resolve(option('--source-root') ?? process.cwd());
const baseUrl = option('--base-url')?.replace(/\/$/, '');

function read(relativePath) {
  return fs.readFileSync(path.join(sourceRoot, relativePath), 'utf8');
}

const privacyHtml = read('web/privacy-policy/index.html');
const deletionHtml = read('web/account-deletion/index.html');
const legalScript = read('web/legal/legal.js');
read('web/legal/legal.css');

assert.match(privacyHtml, /data-legal-page="privacy-policy"/);
assert.match(privacyHtml, /data-release-status="owner-input-required"/);
assert.match(
  privacyHtml,
  /not an approved privacy policy/i,
  'the owner-input placeholder must fail closed',
);
assert.doesNotMatch(
  privacyHtml,
  /\[(?:owner|legal|contact|address|url)[^\]]*required[^\]]*\]/i,
  'release-template prompts must not appear as public legal copy',
);

assert.match(deletionHtml, /data-legal-page="account-deletion"/);
assert.match(deletionHtml, /data-non-enumerating="true"/);
assert.match(deletionHtml, /does not reveal whether an account exists/i);

const publicAssets = `${privacyHtml}\n${deletionHtml}\n${legalScript}`;
assert.doesNotMatch(publicAssets, /<form\b|<input\b|<textarea\b/i);
assert.doesNotMatch(publicAssets, /flutter_bootstrap|firebase|app[ _-]?check/i);
assert.doesNotMatch(publicAssets, /\bfetch\s*\(|XMLHttpRequest/i);
assert.doesNotMatch(
  publicAssets,
  /\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i,
  'no unapproved contact identifier may be published',
);

const sandbox = {};
vm.runInNewContext(legalScript, sandbox, { filename: 'web/legal/legal.js' });
const dictionaries = sandbox.EchoMeetLegalCopy;
assert.deepEqual(Object.keys(dictionaries), ['en', 'de', 'sq']);
const englishKeys = Object.keys(dictionaries.en).sort();
for (const locale of ['en', 'de', 'sq']) {
  assert.deepEqual(Object.keys(dictionaries[locale]).sort(), englishKeys);
  for (const [key, value] of Object.entries(dictionaries[locale])) {
    assert.equal(typeof value, 'string', `${locale}.${key} must be a string`);
    assert.notEqual(value.trim(), '', `${locale}.${key} must not be empty`);
  }
}
assert.notEqual(dictionaries.en.privacy_title, dictionaries.de.privacy_title);
assert.notEqual(dictionaries.en.deletion_title, dictionaries.sq.deletion_title);

for (const html of [privacyHtml, deletionHtml]) {
  const referencedKeys = [
    ...html.matchAll(/data-i18n(?:-aria-label)?="([^"]+)"/g),
    ...html.matchAll(/data-title-key="([^"]+)"/g),
  ].map((match) => match[1]);
  for (const locale of ['en', 'de', 'sq']) {
    for (const key of referencedKeys) {
      assert.ok(
        dictionaries[locale][key],
        `${locale} is missing static-page key ${key}`,
      );
    }
  }
}

const firebase = JSON.parse(read('firebase.json'));
assert.equal(firebase.hosting.public, 'build/web');
const rewrites = firebase.hosting.rewrites;
const catchAllIndex = rewrites.findIndex((entry) => entry.source === '**');
assert.ok(catchAllIndex >= 0, 'Flutter catch-all rewrite is missing');
for (const [source, destination] of [
  ['/privacy-policy', '/privacy-policy/index.html'],
  ['/privacy-policy/**', '/privacy-policy/index.html'],
  ['/account-deletion', '/account-deletion/index.html'],
  ['/account-deletion/**', '/account-deletion/index.html'],
]) {
  const index = rewrites.findIndex(
    (entry) => entry.source === source && entry.destination === destination,
  );
  assert.ok(index >= 0, `missing Hosting rewrite ${source}`);
  assert.ok(index < catchAllIndex, `${source} must precede the app catch-all`);
}

console.log('PASS source contract: 4 assets, 3 locales, 4 legal rewrites');

if (baseUrl) {
  const routes = [
    ['/privacy-policy', 'privacy-policy'],
    ['/privacy-policy/', 'privacy-policy'],
    ['/account-deletion', 'account-deletion'],
    ['/account-deletion/', 'account-deletion'],
  ];

  const expectedOrigin = new URL(baseUrl).origin;
  for (const route of ['/privacy-policy', '/account-deletion']) {
    const response = await fetch(`${baseUrl}${route}`, { redirect: 'manual' });
    assert.ok(
      [301, 302, 307, 308].includes(response.status),
      `${route} must canonicalize safely instead of returning ${response.status}`,
    );
    const destination = new URL(response.headers.get('location'), baseUrl);
    assert.equal(destination.origin, expectedOrigin);
    assert.equal(destination.pathname, `${route}/`);
  }

  let pageResponses = 0;
  for (const [route, marker] of routes) {
    for (let attempt = 1; attempt <= 2; attempt += 1) {
      const response = await fetch(`${baseUrl}${route}`, { redirect: 'follow' });
      assert.equal(
        response.status,
        200,
        `${route} attempt ${attempt} returned ${response.status}`,
      );
      const resolved = new URL(response.url);
      assert.equal(resolved.origin, expectedOrigin);
      assert.equal(
        resolved.pathname,
        route.endsWith('/') ? route : `${route}/`,
      );
      assert.match(response.headers.get('content-type') ?? '', /text\/html/i);
      const body = await response.text();
      assert.match(body, new RegExp(`data-legal-page="${marker}"`));
      assert.doesNotMatch(body, /flutter_bootstrap|firebase|app[ _-]?check/i);
      pageResponses += 1;
    }
  }

  for (const asset of ['/legal/legal.js', '/legal/legal.css']) {
    const response = await fetch(`${baseUrl}${asset}`, { redirect: 'manual' });
    assert.equal(response.status, 200, `${asset} returned ${response.status}`);
  }

  console.log(
    `PASS Hosting emulator: ${pageResponses} signed-out page responses ` +
      '(slash/no-slash plus repeat GET), 2 canonical redirects, and 2 static assets',
  );
}
