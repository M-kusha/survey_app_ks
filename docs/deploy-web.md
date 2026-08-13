# Deploying the web app

```bash
flutter build web --release --csp --no-web-resources-cdn \
  --dart-define=FIREBASE_APP_CHECK_WEB_KEY=<reCAPTCHA v3 site key>
```

```bash
npx firebase deploy --only hosting
```

Live at https://echomeet-app.web.app

## Why those flags

**`--no-web-resources-cdn`** serves CanvasKit from our own origin. Flutter
otherwise fetches `canvaskit.wasm` from `www.gstatic.com`, which the
Content-Security-Policy blocks under `connect-src` — the app loads to a blank
page with only a console error to show for it. Serving it ourselves also removes
a third-party dependency from first paint.

**`--csp`** disables dynamic code generation in the compiled output.

**`--dart-define=FIREBASE_APP_CHECK_WEB_KEY`** is required: a release web build
throws at startup without it (`app_check_bootstrap.dart`). It is the reCAPTCHA
**site** key, which is public and ships in the JavaScript. The **secret** key
belongs in the Firebase console and must never enter this repository.

## The CSP, and one deliberate weakening

The policy lives in `firebase.json` under `hosting.headers`. Everything is
strict — `default-src 'self'`, `object-src 'none'`, `frame-ancestors 'none'`,
and an explicit `connect-src` allowlist — with one exception:

`script-src` includes **`'unsafe-inline'`**.

This is not laziness, and it is worth understanding before anyone tries to
tighten it:

`firebase_core_web` injects one inline `<script>` per Firebase product
(`window.ff_trigger_firebase_auth`, `..._firestore`, `..._functions`, and so on
— seven in this app). Each has different content, so each needs its own hash,
and every one changes when the Firebase SDK version changes. Nonces are the
other option, and Firebase Hosting serves static files, so it cannot generate
them per request.

Mitigation that is actually in place: FlutterFire creates a **Trusted Types**
policy for those injections where the browser supports it, which constrains what
can be injected even with `'unsafe-inline'` present.

If this ever needs to be strict, the route is to pre-load the Firebase JS SDKs
with `<script src>` tags in `web/index.html` so the package finds them already
loaded and never injects anything.

## Hosts the policy has to allow, and why

| Host | Directive | Needed for |
|---|---|---|
| `www.gstatic.com` | `script-src` | Firebase JS SDK modules |
| `fonts.gstatic.com` | `connect-src`, `font-src` | the engine's Roboto fallback font |
| `apis.google.com` | `script-src`, `frame-src` | Firebase Auth's popup/redirect resolver, which loads `api.js` at startup whether or not a popup is ever used |
| `www.google.com/recaptcha/` | `connect-src`, `frame-src` | App Check attestation |
| `*.cloudfunctions.net` | `connect-src` | the callables |
| `*.googleapis.com` | `connect-src` | Firestore and Storage |

## After deploying

The browser caches `index.html`, and the CSP arrives as a **response header on
that document** — so a stale cached page carries a stale policy, and the console
will report violations against a policy that is no longer live. Confirm what is
actually being served before believing the console:

```bash
curl -sI https://echomeet-app.web.app/ | grep -i content-security-policy
```

A hard reload (Ctrl+Shift+R) picks up the new document.
