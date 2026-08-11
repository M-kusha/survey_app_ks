# Google Play Data safety answers

Answers for the Data safety form in Play Console, derived from what the code
actually does. Each row cites where to check it, so a future change that makes a
row wrong can be found rather than guessed at.

The published policy these answers must agree with is
`web/privacy-policy/index.html`, served at
`https://echomeet-app.web.app/privacy-policy`. Change one and change the other.

## The two answers people get wrong

**"Is any data shared with third parties?" — No.**
Play defines sharing as a transfer to another *company*. A transfer to a service
provider that processes data on your instructions is explicitly excluded, and
Google/Firebase is the only recipient — it is the processor, not a third party.
There is no analytics, advertising, or attribution SDK to share with: see the
dependency list in `pubspec.yaml`, which contains no `firebase_analytics`, no
`firebase_crashlytics`, and no ad network.

**"Is data collected?" — Yes, and it is not "collected ephemerally".**
Everything below is written to Cloud Firestore or Cloud Storage and persists, so
none of it qualifies for the ephemeral-processing exemption.

## Data types to declare

Every row: **collected = yes, shared = no, encrypted in transit = yes, can be
deleted on request = yes.** "Optional" means the user can use the app without it.

| Play category → type | What it is | Required? | Purposes | Where in the code |
| --- | --- | --- | --- | --- |
| Personal info → Name | Full name, shown to colleagues beside results and votes | Required | App functionality, Account management | `users/{uid}.fullName`, projected to `memberDirectory` |
| Personal info → Email address | Sign-in identity, held by Firebase Authentication | Required | App functionality, Account management | Firebase Auth; mirrored to `users/{uid}.email` |
| Personal info → User IDs | Firebase Auth UID, the key every record hangs off | Required | App functionality | document ids throughout `firestore.rules` |
| Personal info → Other info | Date of birth, entered at registration | Required | App functionality | `users/{uid}.birthdate` |
| Photos and videos → Photos | Optional profile photo, re-encoded server-side as JPEG | Optional | App functionality | `profile_images/{uid}/avatar.jpg`, `functions/src/profile_images.ts` |
| App activity → Other user-generated content | Private notes; survey and test answers and scores; which meeting times you can attend | Optional | App functionality | `users/{uid}/notes`, `surveys/{id}/participants`, `appointments/{id}/participants` |
| Device or other IDs → Device or other IDs | Firebase Cloud Messaging registration token, one per device that permits notifications | Optional | App functionality | `users/{uid}.fcmTokens`, capped at 10 |

Declare nothing under Location, Financial info, Health and fitness, Messages,
Contacts, Calendar, Search history, Web browsing, Installed apps, App
interactions, Crash logs, Diagnostics, or Audio. None is read, and no code path
exists that could.

Two rows deserve a note when filling the form:

- **Other user-generated content is optional but visible to others.** Survey and
  test answers and their scores are readable by the administrators and
  moderators of the user's own company; meeting votes are readable by that
  company's members; notes are readable by nobody but their author. That
  in-company visibility is not "sharing" in Play's sense — it does not leave the
  operator's system — but it does belong in the policy, and it is stated there.
- **The FCM token is a device identifier.** It is declared even though it is only
  used to deliver notifications, because Play treats a per-device token as an ID
  regardless of purpose. It is optional: a user who never grants the
  notification permission has none stored.

## Security practices section

| Question | Answer | Why |
| --- | --- | --- |
| Data is encrypted in transit | Yes | Every Firebase SDK connection is TLS; `firebase.json` also sets HSTS on the web origin |
| You provide a way for users to request data deletion | Yes | In-app, Settings → Delete account (`functions/src/account_deletion.ts`); public instructions at `/account-deletion` |
| Data deletion URL | `https://echomeet-app.web.app/account-deletion` | Static page, reachable signed out, asks for no identifier |
| Committed to follow the Play Families Policy | No | The app is not directed at children; the policy states an under-16 exclusion |
| Independent security review | No | None has been commissioned — do not claim one |

## Permissions and app access

The app's own manifest declares only `android.permission.INTERNET`
(`android/app/src/main/AndroidManifest.xml`). Plugins merge in more at build
time — `firebase_messaging` adds `POST_NOTIFICATIONS`, `image_picker` adds camera
and media access. Before submitting, read the **merged** manifest of the actual
release build rather than trusting this list:

```bash
aapt2 dump permissions build/app/outputs/bundle/release/app-release.aab
```

Play also asks how a reviewer signs in. EchoMeet needs a verified email address
and a company to show anything, so a reviewer landing on an empty account sees
almost nothing. Supply, under App access → All or some functionality is
restricted:

- a demo account whose email is already verified,
- the company join code or an already-approved membership on it,
- a note that surveys and meetings are visible only inside a company.

## Before you submit

- [ ] `flutter build web --release` and deploy, then open both public pages from
      a signed-out browser and refresh each one directly (the Hosting rewrites
      are what make a direct refresh work).
- [ ] Paste `https://echomeet-app.web.app/privacy-policy` into Play Console →
      Store listing → Privacy policy.
- [ ] Paste `https://echomeet-app.web.app/account-deletion` into Data safety →
      Data deletion.
- [ ] Fill the table above, then re-read the published policy and confirm the two
      say the same thing.
- [ ] Delete the App Check debug token before shipping — it bypasses attestation
      (`docs/app-check.md`).

If the origin ever changes, `PublicRoutePaths.canonicalOrigin` and the link in
`functions/src/messaging.ts` both have to move; a test in
`test/unit/public_legal_pages_test.dart` fails if only one of them does.
