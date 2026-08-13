# EchoMeet — audit findings

Date: 13 August 2026 · Commit: `d40ead6` · 30,632 lines of Dart across 146 files,
plus 20 TypeScript function modules.

Everything below was **verified in the code**, not inferred. Where I could not
verify something from the repository alone it is marked *unverified* and says
what would settle it. Line references are to the commit above.

Severity is about what a user or a reviewer would actually experience:

| | meaning |
|---|---|
| **S1** | Someone hits this on a normal path and is blocked or misled |
| **S2** | Real defect, but needs an unlucky sequence or only wastes money/time |
| **S3** | Debt or risk: nothing broken today, costly or dangerous later |

---

## S1 — blocking

### 1. The first person to register as a plain user reaches a dead end

`lib/register/register_4step.dart:110`

```dart
onContinue: _selectedId == null || _saving ? null : _finish,
```

Step 4 is a company picker. Continue is disabled until a company is selected,
and when none exist the screen shows `no_companies_yet` with no other action.
There is no "create one instead", no "join later", no back-out.

So on an empty deployment — which is exactly what a stranger opening the
showcase finds — choosing "register as user" ends the flow permanently. The
account exists in Auth, the profile is written, and the person cannot proceed.

This is the highest-value fix in the list because it is the *first* screen a
new visitor can get stuck on, and everything else is behind it.

**Decision needed before fixing:** does the first user create a company, join
nothing and land in a "you are not in a company yet" state, or get pushed to the
company-creation branch? The membership layer already models a companyless
account (`CompanyGate`), so the second is cheap.

---

## S2 — real defects

### 2. Automatic push re-registration fails silently

`lib/core/notifications/push_service.dart:119`

```dart
try {
  await startIfEnabled(expectedUid: current!.uid);
} catch (_) {}
```

`startIfEnabled` returns a `PushStartResult` (`registered`, `disabled`,
`unavailable`). Here the result is discarded *and* the exception is swallowed
with no log, in debug or release.

The interactive path is fine — `lib/settings/notifications_options.dart:72-84`
inspects the result, throws on failure and resets the switch. But the automatic
re-registration after sign-in (`lib/login/login.dart:353`, also `unawaited`)
records nothing anywhere. A person whose token never registers has notifications
switched **on** in Settings and no notifications, with nothing in the app or the
logs saying why.

This matters right now: Play Services logged `DEVELOPER_ERROR` on the test
device, which is the class of failure this path hides.

**Fix:** keep the last failure on `PushService`, surface it in the notifications
row ("Notifications may not be working — retry"), and `debugPrint` in debug.

### 3. Deleting a survey reads every response to show a number

`lib/survey_pages/main_sruvey/survey_list.dart:209` and `:267`

```dart
await provider.loadParticipants(survey.id);
final responses = provider.participants?.length ?? 0;
```

The delete confirmation and the duplicate action both load the entire
participants subcollection to render one count. With the 40 seeded people that
is up to 40 document reads per dialog open, on a screen where someone may be
tidying up several surveys in a row.

**Fix:** Firestore's `count()` aggregation reads one billed unit instead of N,
or keep a counter on the parent (the `responsesRevision` field already proves
the trigger can maintain one).

### 4. Two providers can notify after disposal

`lib/login/session_access.dart:47` and `lib/settings/font_size_provider.dart:25`

`SessionAccess._setUnlocked` calls `notifyListeners()` from an auth-state
subscription; `dispose()` cancels the subscription but an event already in
flight still lands. `FontSizeProvider._restore()` is async, calls
`notifyListeners()` when SharedPreferences returns, and the class has no
`dispose` override and no disposal flag at all.

Both throw *"A ChangeNotifier was used after being disposed"* if the widget
tree is torn down at the wrong moment — sign-out, or a hot restart.

Every other provider in the codebase already guards this
(`appointment_provider.dart`, `membership.dart`, `survey_data_provider.dart`,
`device_time_zone.dart` all carry a `_disposed` flag). These two are the
exceptions, which is what makes them a bug rather than a style choice.

### 5. Seeded demo members cannot be administered

`tool/seed_demo_people.js` writes `users/{id}` and `memberDirectory/{id}` for 40
people who have no Firebase Auth account. The trusted callables
(`functions/src/company_administration.ts`) resolve the target through
`getAuth().getUser(uid)`, which fails for them.

So ban, unban, role change and remove all error out on any seeded person. The
member list is populated and looks right, and the actions on it do not work.

**Fix:** either accept it and note it in the demo script, or have the seeder
create real Auth users through the Admin SDK (`createUser`) so every
administrative action works end to end. The second is about ten lines and makes
the demo honest.

---

## S3 — debt and risk

### 6. App Check is enforced on callables but not on Firestore

*Unverified from the repository — this is a console setting.*

Every callable sets `enforceAppCheck: true` (`functions/src/index.ts`), so the
trusted write paths are attested. Firestore itself only enforces App Check when
it is switched on for the API in the Firebase console.

Until that is on, a caller with a stolen ID token can talk to Firestore directly
from outside the app. The rules still constrain *what* they can do — that is the
real boundary and it is thorough — but the attestation layer has a hole in it.

**Settle it by:** Firebase console → App Check → APIs → Cloud Firestore →
enforcement state. Turn it on *after* the debug tokens are removed, or the app
stops working on your own devices.

### 7. Two debug tokens still bypass attestation

- web `6e7b913a-959f-41bb-ae39-a0450c2514d6`
- Android `ce7c4706-b0db-482e-879c-18f74b7e95f0`

Both are registered in the console and both are baked into the local build
commands. Anyone holding either can pass App Check from anywhere. They must be
deleted before the app is public, and the release web build needs a real
reCAPTCHA v3 key to replace the web one.

### 8. Two golden tests hang rather than fail

`test/golden/auth_screens_test.dart` — the `de` and `sq` localisation cases are
`skip: true`. They do not fail; they time out after ~7 minutes each, verified
against a clean checkout, so they were costing 14 minutes of every full run
before being skipped.

The cause is the trap the file's own setup describes: with a non-English locale
the `Localizations` delegates cannot resolve and `pumpAndSettle` never settles.
Skipping stopped the bleeding; the German and Albanian auth screens are now
**untested**.

### 9. Two files are past the size where they can be read in one sitting

- `lib/settings/settings.dart` — 880 lines
- `lib/survey_pages/utilities/survey_data_provider.dart` — 727 lines

The provider is the one that matters: it holds four independent subscriptions,
each with its own generation counter, disposal flag and first-load completer.
The pattern is correct — it is the same one that fixed the appointment list —
but it is copied four times in one file and three more times across the other
providers.

**Worth extracting**, not rewriting: one small `WatchedCollection` type owning
*subscribe → generation → error → first-load*, leaving each provider to say what
it maps. That removes the copies without touching the architecture.

### 10. `participants` is written to every survey and never meaningfully read

`functions/src/survey_publication.ts` writes `participants: []` on creation, and
`lib/survey_pages/utilities/survey_questionary_class.dart:60` parses it — but
responses live in the `participants` **subcollection**, which is what every
screen actually reads.

The array is a vestige of an older shape. It is harmless today, and it is the
kind of thing that later gets "fixed" by someone writing into it.

### 11. State management is otherwise sound — do not refactor it

Recorded because it is easy to assume the opposite: the Provider setup is
conventional and appropriate. Seven `ChangeNotifier`s, each owning one concern,
five of them already guarding disposal correctly.

Every failure found this week came from layout constraints, Firestore trigger
semantics, or schema mismatches — **none** from state architecture. A rewrite
would cost days and change nothing anyone can see.

---

## What is genuinely absent

Not bugs, but gaps a reviewer might notice:

1. **No README worth the name.** The reasoning behind this codebase — rules as
   the security boundary, server-side grading, the answer key in a separate
   collection, the two-phase delete — exists only in commit messages. Anyone
   assessing the repository reads that file first.
2. **No CI.** 466 tests and an analyzer that stays clean, run by hand. A GitHub
   Actions file is half an hour and makes the discipline visible.
3. **Nothing is deployed.** Firebase Hosting is configured and has never been
   run. Until it is, the app cannot be looked at without a laptop and a phone.
4. **Notifications are unproven end to end.** They have never been observed
   arriving on a device, and finding 2 explains why a failure would be invisible.

---

## Suggested order

1. **Finding 1** — the registration dead end. Nothing else matters if the first
   screen traps people.
2. **Deploy to Firebase Hosting** — needs the reCAPTCHA key first. Deployment
   also surfaces release-only bugs (tree-shaking, real attestation, CORS) that
   cannot be found locally.
3. **Finding 2**, then **3 and 4** — the defects, cheapest first.
4. **README**, then **CI**.
5. **Findings 6 and 7** together, immediately before going public.
6. **Finding 9** only if there is appetite; it is invisible to users.
