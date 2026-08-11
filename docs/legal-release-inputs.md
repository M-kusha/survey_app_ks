# Privacy, deletion, and store release inputs

This file records the owner decisions the published policy rests on, and what is
still outstanding before a store release. It is not legal advice, and it is not
evidence that anything has been deployed.

The policy itself is `web/privacy-policy/index.html` with its copy in
`web/legal/legal.js`; the in-app summary is `lib/settings/privacy_policy_info.dart`
with keys under `privacy_policy_*`. Google Play's Data safety answers are in
`docs/play-data-safety.md`.

## Owner decisions

| Input | Value |
| --- | --- |
| Controller/operator legal identity | Kushtrim Mulliqi, acting as an individual |
| Controller/operator postal address | Not published. A contact address is given instead; GDPR requires identity and a contact route, not a postal address, and publishing a home address on an indexed page is worse for the operator than omitting it. |
| Privacy/support contact | `kushtrim.mulliqi@outlook.com` |
| Policy effective date | 12 August 2026 |
| Production origin | `https://echomeet-app.web.app` — Firebase Hosting default. A custom domain is intended later; see *Moving the origin* below. |
| Public privacy-policy URL | `https://echomeet-app.web.app/privacy-policy` |
| Public account-deletion URL | `https://echomeet-app.web.app/account-deletion` |
| Age position | Not intended for or directed at under-16s; stated in the policy |
| Signed-out help path | Password reset on the sign-in screen. The public deletion page asks for no identifier and performs no lookup, so it cannot reveal whether an account exists. |
| Legal review | None commissioned. The policy describes verified code behaviour and claims nothing beyond it. |

The policy makes no claim that could not be checked against this repository. Two
deliberate limits on its wording:

- It does not promise a backup retention period. It says deletion removes the
  records from the live database and that copies inside Google's infrastructure
  expire on Google's schedule — which is true and verifiable, where a specific
  number would not be.
- It does not list Google sub-processors individually. It names Google as the
  only processor and names each Firebase service in use, with regions.

## Purposes, legal bases, and retention

| Category | Purpose | Legal basis (GDPR Art. 6) | Retention |
| --- | --- | --- | --- |
| Email, name, date of birth | Provide the account | Contract, 6(1)(b) | Life of the account |
| Company, role, approval state | Provide the shared workspace | Contract, 6(1)(b) | Life of the account, or until the member leaves |
| Profile photo (optional) | Identify a colleague in results and votes | Contract, 6(1)(b) | Until replaced or the account is deleted |
| FCM token, notification locale | Deliver notifications the user permitted | Consent, withdrawable in device settings | Until the device unregisters or a send reports the token dead (`functions/src/messaging.ts` prunes it) |
| Notes | Provide the notes feature | Contract, 6(1)(b) | Until deleted by the author or the account is deleted |
| Survey/test answers and scores | Provide surveys and tests | Contract, 6(1)(b) | Until the account or the company is deleted |
| Meeting votes | Provide meeting scheduling | Contract, 6(1)(b) | Until the account or the meeting is deleted |
| Administrative and ban records | Keep an accountable record of who changed access | Legitimate interests, 6(1)(f) | Life of the company |
| App Check attestation | Confirm requests come from the genuine app | Legitimate interests, 6(1)(f) | Not stored by EchoMeet |

Company closure schedules deletion seven days out and then removes that
company's surveys, tests, answers and meetings; members are released, not
deleted (`functions/src/purge.ts`).

## Processors

Google is the only processor. Services in use, with location:

| Service | Purpose | Location |
| --- | --- | --- |
| Firebase Authentication | Sign-in, email verification, password reset | Google-managed |
| Cloud Firestore | Every record described above | `eur3`, Europe multi-region |
| Cloud Storage | Profile photos | `echomeet-app.firebasestorage.app` |
| Cloud Functions (v2) | Trusted writes, scoring, deletion, notifications | `europe-west4`, Netherlands |
| Firebase Cloud Messaging | Notification delivery | Google-managed, plus the device's own push service |
| Firebase App Check | Attestation via reCAPTCHA (web) and Play Integrity (Android) | Google-managed |
| Firebase Hosting | The web app and the legal pages | Google edge |

## Outstanding before a store release

- [ ] Deploy, then verify both public pages from a signed-out browser including a
      direct refresh of each URL.
- [ ] Verify the in-app privacy and deletion links in all three locales.
- [ ] Exercise account deletion end to end against a real account and confirm
      each collection named in the policy is actually emptied. The policy claims
      what the code intends; only a run proves it.
- [ ] Fill Play Console per `docs/play-data-safety.md`.
- [ ] Delete the App Check debug token (`docs/app-check.md`).

## Moving the origin

The origin appears in exactly three places, and a test keeps two of them honest:

1. `PublicRoutePaths.canonicalOrigin` — the in-app link and displayed URL.
2. `functions/src/messaging.ts` — the link a web notification opens.
3. Play Console — the privacy-policy and data-deletion URLs.

`test/unit/public_legal_pages_test.dart` fails if 1 and 2 disagree. Nothing can
check 3 from here, so change it in the same sitting.
