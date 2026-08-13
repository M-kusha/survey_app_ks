# EchoMeet

**Live: https://echomeet-app.web.app** · [Privacy policy](https://echomeet-app.web.app/privacy-policy) · [Account deletion](https://echomeet-app.web.app/account-deletion)

A Flutter and Firebase app for small companies: shared **notes**, **meeting
scheduling** by availability poll, and **surveys and graded quizzes** with
scoring, review and PDF export.

Built solo in 2023–24 and rebuilt from the ground up in 2026: a hardened
security model with an emulator-backed rules suite, a company membership
system, server-side notifications, and a complete Material 3 redesign.

---

## Contents

- [What it does](#what-it-does)
- [The 2026 rebuild](#the-2026-rebuild)
- [Membership: the core model](#membership-the-core-model)
- [Security](#security)
- [Architecture](#architecture)
- [Testing](#testing)
- [Notifications](#notifications)
- [Running it](#running-it)
- [Deploying](#deploying)
- [Roadmap](#roadmap)

---

## What it does

A company is the unit everything hangs off. People join one, and its content is
visible to its members and to nobody else.

### Notes

Private to the person, not the company — the one thing that survives being
removed, banned, or having no company at all.

Rich text via Quill, **autosaved** 1.2 seconds after typing stops and flushed
again on the way out, with a status line saying which state you are in. The list
shows the opening of each note, when it was last edited, and a pin that outranks
whatever sort order is active.

### Meetings

An admin proposes time slots; everyone votes **yes / maybe / no** on each. The
vote page shows running totals per slot as they arrive, and the admin confirms
one — which locks the poll and tells everybody.

Votes can be changed until the deadline passes or a slot is confirmed. That is
deliberate: a scheduling poll asks "when can you make it", and that answer
genuinely changes. Locking the first response gets you a wrong meeting time plus
a message asking you to fix it by hand.

### Surveys and quizzes

Two things behind one authoring flow:

- a **survey** collects opinions and has no right answers
- a **quiz** is graded, has a pass mark, and can be timed per question

Question types are single choice, multiple choice and free text. Multiple choice
is scored proportionally — right options earn, wrong ones subtract, floored at
zero — so guessing everything scores zero rather than full marks.

Free-text answers are marked by an admin afterwards, as **correct / incorrect /
not yet reviewed**, which are three distinct facts about somebody's paper.
Marking one re-grades the whole submission rather than adjusting a stored total.

Leaving a timed quiz submits what you have. It does not discard the attempt and
let you start again, and the security rules only permit `create` on a response,
never `update` — so a second attempt is refused by the server even if the UI is
bypassed.

Results export as PDF for one person or for a whole group (everyone / passed /
not passed), plus an analytics report for surveys.

---

## The 2026 rebuild

The first version was a working prototype. The rebuild took it to something that
holds up in real use, along three lines.

### Hardened

The database previously had **no server-side protection at all** — every rule
that mattered lived in the UI, and the UI is a suggestion. Now:

- Firestore and Storage rules, with more than 100 cases against the emulators
- Company isolation: one company's data is unreachable from another
- Two levels of privilege enforced in rules, not just hidden in the interface
- `superadmin` grantable only at company creation, never afterwards, by anyone
- One attempt per graded quiz, enforced server-side — a response allows `create`
  and never `update`, so a score cannot be rewritten by the person who earned it
- Ordered cascading deletes, so removing a survey or a company cannot strand its
  subcollections
- A grace period on company deletion enforced by `request.time`, not by a
  countdown in the client

### Extended

- **Membership as a real model** — join, approval queues, bans, removal, and a
  route back for anyone who loses a company
- **Scheduled company closure** with a week's grace and a banner for every member
- **Push notifications** — six notification handlers within fifteen deployed
  backend functions, covering new surveys, meetings, confirmed times, join
  requests and deadline reminders
- **Notes** gained autosave, body previews, pinning and editable titles
- **PDF export** for individuals, filtered groups and survey analytics
- **Proportional scoring** for multiple choice — right options earn, wrong ones
  subtract, floored at zero
- **Three languages**, 747 keys each, with locale-correct dates everywhere
  including inside generated PDFs

### Redesigned

Every screen was rebuilt on a Material 3 design system with a shared widget kit,
a responsive layout that adapts from phone to desktop rather than stretching,
and golden tests to keep it from drifting.

### The engineering thread

One idea runs through most of the correctness work: **derive, don't accumulate.**

A stored total that a second code path also adjusts will eventually disagree
with the thing it summarises. Scores, vote counts, note filters and list headers
were each keeping a running figure that some other branch could nudge — and each
of them drifted. They are now computed from the source on read, and the pure
modules that do it (`SurveyScorer`, `vote_tally`, `note_query`, `deadline`) hold
no Firebase and no Flutter types, so the rules they encode are tested directly
rather than by driving a screen.

---

## Membership: the core model

Membership is not a fact fixed at sign-up. There are four states, and the app
says something different for each:

| State | What it means | What works |
| --- | --- | --- |
| **No company** | Hasn't joined one, or was removed | Notes; can browse and join |
| **Pending** | Joined a company that reviews new members | Notes; waiting |
| **Banned** | Barred by the company | Notes; can leave and join elsewhere |
| **Active** | Full member | Everything |

An account outlives its membership. Being banned or removed costs you that
company's content and nothing else — your login, your notes and your ability to
go somewhere else are untouched.

**A ban is a document under the company** — `companies/{id}/bans/{uid}` — not a
flag on the person. That is what makes the above work: the company keeps a list
it can lift bans from, which a flag on the user document would lose the moment
that person joined somewhere else.

Companies choose whether new members are admitted immediately or held for
approval. The resulting status is decided **by the security rules from the
company's own policy**, not sent by the client — otherwise "approval required"
would be a suggestion anyone could decline by editing one field of their sign-up
payload.

### Closing a company

The owner can close their company. It is scheduled a week out, every member sees
a banner for the duration, and the owner can call it off at any point.

The wait is enforced by Firestore — `request.time >= deletionScheduledFor` —
because a grace period that lives only in the client lasts until somebody sends
the request themselves, and this one destroys everybody's work.

When it runs: surveys, answers, meetings, votes, the ban list, the company and
its name reservation all go. **Accounts, passwords and notes do not.** Every
member is released to join somewhere else.

---

## Security

Firestore rules are the enforcement point; the UI only decides what to draw.

### Two levels of privilege

| | Content: surveys, meetings, results, marking | People: roles, bans, removals |
| --- | --- | --- |
| Moderator | yes | **no** |
| Admin | yes | yes |
| Owner | yes | yes, plus closing the company |

`isStaff()` and `isCompanyAdmin()` are separate functions in the rules for
exactly this reason. A moderator who can promote is an admin with extra steps.

### Other properties worth knowing

- Company names are unique. Firestore cannot constrain a field, but a document
  id is unique by definition, so `companyNames/{slug}` with create-allowed and
  update-forbidden is a uniqueness constraint that holds under a race.
- `superadmin` is only accepted at sign-up when the `companyId` names a company
  the same user just created, and can never be granted afterwards by anyone.
- A response to a survey allows `create` but never `update`, so scores cannot be
  rewritten by the person who earned them.
- Deletes cascade in the right order. Firestore does not cascade at all, and the
  rule guarding a child reads its parent's `companyId` — so removing the parent
  first denies every child delete and strands the subcollection. Children first,
  batched, parent last.
- Account deletion runs at a trusted server boundary with recent-authentication
  enforcement. An owner must explicitly accept that deleting their account also
  destroys every company they own; other members keep their accounts and notes.
  An admin still cannot ban themselves.

Unauthenticated registration reads only `companyDirectory`, a public projection
containing a company name and join policy. Ownership, deletion metadata and
other tenant state remain private. Company and profile creation are deferred
until the Auth account has verified its email, and a trusted callable completes
the public/private documents atomically.

---

## Architecture

```
lib/
├── core/
│   ├── layout/        breakpoints, PageBody — one place for page width
│   ├── theme/         M3 ColorScheme.fromSeed, success/warning/info extension
│   ├── widgets/       EmptyState, ContentCard, StatusPill, WizardScaffold …
│   ├── time/          deadlineFor() — pure, tested
│   ├── membership/    the four states, joining, bans, company admin
│   ├── notifications/ FCM registration and foreground display
│   └── localization/  supported locales, in one list
├── login/  register/  reset_password/
├── notes/             list, editor, and a pure query module
├── appointments/      create, edit, vote, confirm, tally
├── survey_pages/
│   ├── create_survey/ authoring and validation
│   ├── user_survey/   answering
│   ├── admin/         participants, per-person review, analytics
│   └── utilities/     SurveyScorer — one graded pass
└── settings/
```

146 files, ~30,800 lines.

**State** is Provider plus local `setState`. Deliberately not Riverpod or Bloc:
the app has three data domains and no cross-screen shared mutable state worth
the ceremony. The pure modules below are where the interesting logic lives, and
they hold no framework types at all.

**Testable cores.** `SurveyScorer`, `vote_tally`, `note_query`, `deadline` and
`validateQuestions` are plain Dart with no Firebase and no Flutter, so the rules
they encode are tested directly instead of by driving a screen.

**Responsive.** Material window size classes — a bottom bar on phones, a
navigation rail on tablets, an extended rail with labels on desktops. Content is
width-capped per screen rather than stretched across a monitor.

**Three languages** — English, German, Albanian — with 747 keys each. Dates go
through `DateFormat` with an explicit locale, including inside generated PDFs,
where there is no `BuildContext` left to read one from.

---

## Testing

| Suite | Count | What it covers |
| --- | --- | --- |
| `rules-tests/` | 155 cases | Firestore and Storage rules, against the emulators |
| `test/unit/` | 50 files | Pure logic — scoring, tallies, queries, deadlines, codecs |
| `test/widget/` | 14 files | Layout geometry and interaction |
| `test/golden/` | 7 files | Design system, navigation and signed-out screens |
| `functions/test/` | 141 cases | Trusted callables, triggers and the activity log |

470 Dart tests and 141 function tests, with the analyzer clean.

```bash
flutter test                       # Dart
cd rules-tests && npm test         # rules (needs Java for the emulator)
```

**The rules tests are the ones that matter most.** They cover what is invisible
from inside the app: that a colleague at another company cannot read your
surveys, that a moderator cannot promote anyone, that a banned member can leave
and join elsewhere but cannot rejoin the company that banned them, that a
pending member cannot approve themselves, and that a scheduled company deletion
cannot skip its week.

Two of them caught real bugs before deploy. `fieldUnchanged` on a field that was
never written is an evaluation *error* in Firestore rules rather than null — so
a first attempt at ban-protection rejected profile edits by every account
created before bans existed.

**The widget tests exist for a specific hazard.** Three times during the rebuild
a screen went blank in release with no error: a widget that expands or collapses
in a slot with unbounded or full constraints throws during layout, and a widget
that fails to build paints nothing at all. `flutter analyze` cannot see it. Those
cases now assert geometry directly.

**The PDF tests build real documents and check the bytes** — header, trailer,
size — because a layout error inside a PDF is invisible to the analyzer and
surfaces as an empty viewer in front of whoever needed the results.

---

## Notifications

Notifications are one part of the 16 Functions exported from `functions/`:

| Trigger | Who hears |
| --- | --- |
| Survey or quiz created | active members, **except the author** |
| Meeting created | active members, except the author |
| Time slot confirmed | everyone who voted, plus everyone who was asked |
| Someone asks to join | admins and the owner, never moderators |
| Daily 09:00 | anyone who has **not yet answered** something closing within 24h |
| Daily 03:30 | carries out company closures whose week has run out |
| Hourly at minute 15 | removes expired account-deletion write locks; sends no message |

Messages are addressed by device token rather than topic: a topic subscription
outlives removal, bans and leaving, so somebody who lost access to a company
would keep hearing from it.

The full 15-export inventory, current schedule, and region constraint are in
[docs/notifications.md](docs/notifications.md). Auth email wording is in
[docs/email-templates.md](docs/email-templates.md) — those live in the Firebase
console, not in this repository.

The operator-owned privacy, contact, retention and store-listing inputs that
cannot be derived from code are tracked in
[docs/legal-release-inputs.md](docs/legal-release-inputs.md).

---

## Running it

Requires Flutter 3.44+ / Dart 3.9+, and a JDK for the rules emulator.

```bash
flutter pub get
flutter run                        # or: flutter run -d chrome
```

The Firebase config in `firebase_options.dart` and `google-services.json` points
at a live project. Those keys are **not secrets** — they identify the project,
they do not authorise anything. Security rules are what protect the data.

To point at your own project:

```bash
flutterfire configure
firebase deploy --only firestore:rules,firestore:indexes,storage --project echomeet-app
```

---

## Deploying

The web app is live at **https://echomeet-app.web.app**, with the privacy policy
and account-deletion instructions served from the same host.

```bash
flutter build web --release --csp --no-web-resources-cdn   --dart-define=FIREBASE_APP_CHECK_WEB_KEY=<reCAPTCHA v3 site key>
npx firebase deploy --only hosting
```

Both flags are load-bearing and the reasons are in
[docs/deploy-web.md](docs/deploy-web.md), along with the Content-Security-Policy
the app has to satisfy — including one deliberate weakening (`'unsafe-inline'`
on `script-src`) that the Firebase web SDK forces, and the route to removing it.
Every failure that document records was invisible locally and only appeared in a
release build.

Backend rollout is ordered, because the privacy projections, private survey
keys, appointment timestamps and canonical avatars need guarded migrations
between specific backend and client releases. Follow
[docs/release-runbook.md](docs/release-runbook.md) from Gate 0; do not deploy
individual rules, Functions or clients out of sequence.

Android release builds fail closed until `android/key.properties` points to a
real upload keystore. See [docs/release-signing.md](docs/release-signing.md).

---

## Roadmap

What comes next, in rough priority order:

- **Release credentials.** Android signing now fails closed when an upload key
  is missing. The private Android keystore, Apple team/provisioning, APNs key,
  web VAPID key and App Check provider keys remain release-environment inputs
  and must never enter this repository.
- **Firebase App Check enforcement.** The web app attests with reCAPTCHA v3 and
  every callable sets `enforceAppCheck`. Enforcement for Firestore itself is a
  console setting and is not yet on, so a stolen ID token can still reach the
  database directly — the rules remain the real boundary either way.
- **Roles as custom claims** rather than Firestore fields. Every rule that
  checks a role currently costs a document read; claims are cheaper and cannot
  be reached by a client at all. Needs a function to set them.
- **Platform keys for push** — an APNs key for iOS, a VAPID key for web. Until
  those exist, devices on those platforms register and then receive nothing.
- **End-to-end encryption for note bodies.** Private by rule today, but readable
  by anyone with database access.
- **CI.** Analysis, tests and rules tests run locally; they should run on push.
