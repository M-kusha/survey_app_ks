# Storage CORS

Profile photos do not appear in the web app until the bucket carries a CORS
configuration. `storage.cors.json` is that configuration; this file explains why
it is needed and how to apply it.

## Why

`AuthenticatedProfileImage` downloads bytes through the Storage SDK rather than
pointing an `<img>` at a download URL, so a token-bearing URL never enters the
page. On web that SDK path ends in an ordinary cross-origin `fetch`, and a fetch
needs the response to carry `Access-Control-Allow-Origin`.

Two endpoints are involved and they behave differently, which is easy to get
wrong:

| Request | `Access-Control-Allow-Origin` |
| --- | --- |
| `/v0/b/<bucket>/o/<object>` — metadata | `*`, always |
| `/v0/b/<bucket>/o/<object>?alt=media` — the bytes | only if the bucket has CORS |

Probing the first one proves nothing about the second. Without bucket CORS the
download returns `200 OK` with no ACAO header, the browser discards it, and the
avatar silently falls back to initials — the failure looks identical to "no
photo set". `authenticated_profile_image.dart` names the reason in debug builds
so this is diagnosable rather than a mystery.

Android and iOS are unaffected: CORS is a browser rule.

## Applying it

The Firebase CLI cannot set bucket CORS — it is a Cloud Storage setting. Either
of these works.

**Cloud Shell, no install.** Open https://console.cloud.google.com/ , start
Cloud Shell, upload `storage.cors.json` (or paste it into a file), then:

```bash
gcloud storage buckets update gs://echomeet-app.firebasestorage.app --cors-file=storage.cors.json
```

**Locally,** with the Google Cloud CLI installed and authenticated:

```bash
gcloud storage buckets update gs://echomeet-app.firebasestorage.app --cors-file=storage.cors.json
```

Confirm it took:

```bash
gcloud storage buckets describe gs://echomeet-app.firebasestorage.app --format="default(cors_config)"
```

## Checking it worked

From a shell, against a real object URL taken from the browser console:

```bash
curl -s -D - -o /dev/null -H "Origin: https://echomeet-app.web.app" "<download-url-with-alt=media>"
```

An `Access-Control-Allow-Origin` line in the response means it is fixed. No such
line means the configuration has not applied yet.

## Origins

The list is deliberately explicit rather than `*`. These objects are private —
rules decide who may read them — and a wildcard would let any site attempt the
read with the visitor's credentials. Add a custom domain here when the app moves
to one, alongside `PublicRoutePaths.canonicalOrigin`; `localhost:4200` is the
port `.claude/launch.json` uses for local development.
