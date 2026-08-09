# Notifications

## What costs money

Cloud Functions are not available on the free **Spark** plan. Running them means
switching the project to **Blaze**, which requires a payment method on the
account. That is a change only the project owner can make, in the Firebase
console, and nothing here does it automatically.

Pricing and free allowances can change, so the release owner must review the
current Firebase and Google Cloud pricing pages rather than treating this file
as a quote. The current source deploys three Scheduler jobs. They produce 26
scheduled invocations on an ordinary day: one reminder sweep, one company-purge
sweep, and an hourly account-deletion-lock sweep. Firestore event triggers and
the three callables add usage when users act. Configure a budget alert before
production deployment.

## Deploying

```bash
firebase deploy --only functions,firestore:indexes --project echomeet-app
```

The indexes matter: the current manifest contains three composite indexes and a
collection-group field override used by trusted account deletion. A successful
submission is not enough; wait until every index reports enabled.

### Deployed inventory

The current `functions/src/index.ts` exports exactly 15 Functions:

| Kind | Exports |
| --- | --- |
| App Check callables | `completeOnboarding`, `uploadProfileImage`, `deleteMyAccount` |
| Survey triggers | `onSurveyCreated`, `onSurveyResponseCreated`, `onSurveyResponseUpdated` |
| Appointment triggers | `onAppointmentCreated`, `onAppointmentVoteCreated`, `onAppointmentVoteDeleted`, `onTimeSlotConfirmed` |
| Membership triggers | `onJoinRequested`, `onJoinRequestedAtRegistration` |
| Scheduler jobs | `remindExpiring`, `purgeScheduledCompanies`, `purgeAccountDeletionLocks` |

Treat an unexpected deletion prompt, region duplicate, or a different export
count as a failed deployment review.

### The region is not a preference

Everything deploys to **`europe-west4`**, and that is dictated by the database.
This project's Firestore is in `eur3`, a Europe multi-region, and Eventarc
routes events out of a multi-region from exactly one place:

| Firestore location | Functions region |
| --- | --- |
| `eur3` | `europe-west4` |
| `nam5` | `us-central1` |
| any single region | the same region |

A v2 Firestore trigger deployed anywhere else cannot be created. The first
attempt used `europe-west1` and failed in a way worth recognising:

```
+  functions[purgeScheduledCompanies(europe-west1)] Successful create operation.
+  functions[remindExpiring(europe-west1)]          Successful create operation.
!  Deploys failed: onSurveyCreated, onAppointmentCreated,
   onTimeSlotConfirmed, onJoinRequested
```

Both scheduled functions succeeded and all four Firestore triggers failed.
Scheduled functions have no region constraint, so a clean split down that line
means the region, not the code.

Check the location before changing it:

```bash
firebase firestore:databases:get "(default)" --project echomeet-app
```

### Container image cleanup

The CLI asks how many days to keep container images. **1** is the right answer
and is the default. They are build artefacts left behind by each deploy, not
your functions, and keeping them accrues a small Artifact Registry bill for
nothing.

## What gets sent

| Trigger | Who hears about it |
| --- | --- |
| A survey or test is created | every active member except the author |
| A meeting is created | every active member except the author |
| A time slot is confirmed | everyone who voted, plus everyone who was asked |
| Somebody asks to join | the company's admins and owner — never moderators |
| Daily at 09:00 | anyone who has *not yet answered* a survey or meeting closing within 24 hours |
| Daily at 03:30 | scheduled company closures whose week has run out are carried out |
| Hourly at minute 15 | expired account-deletion write locks are removed; this sends no message |

Two decisions worth keeping:

**The author is left out of their own announcement.** Being notified about the
thing you just wrote is the fastest way to teach somebody that these are noise.

**Reminders only go to people who still have something to do.** A "closing
tomorrow" sent to somebody who answered last week is the notification that makes
people turn all of them off.

## Delivery

Messages are addressed to **device tokens**, not topics. Topics are simpler but
a subscription made on a device survives everything the membership model does —
being removed, banned, or leaving — so somebody who lost access to a company
would keep hearing from it. Tokens live in `users/{uid}.fcmTokens`, the same
document the rest of the app already reasons about.

That private document also stores `notificationLocale` (`en`, `de`, or `sq`).
The sender groups tokens by the user's chosen app language; an older profile
without the field safely falls back to English.

Tokens rot: apps are uninstalled, browsers are cleared. The sender prunes any
token that comes back permanently invalid, and only those two error codes —
a transient failure must never cost somebody their registration.

## The bit push cannot do

While the app is **open**, the operating system draws nothing at all. That is
not a bug; a foreground message is delivered to the app and it is the app's job
to decide what to do with it. `PushService` shows it through
`flutter_local_notifications`, which is why both packages are needed.

On **web**, FCM delivers foreground messages through `onMessage` but does not
draw a system notification. EchoMeet therefore shows a localized in-app banner
with an Open action. The native local-notifications plugin remains skipped
because it has no web implementation.

Every message carries a non-sensitive type and document ID. Tapping a survey,
meeting, or approval opens the corresponding app tab on Android, iOS, and web
after the verified-session and optional biometric gate. A cold start retains
the pending destination until the gate is unlocked; it never bypasses access
checks.

## Before the first send

1. **Android** — nothing. `google-services.json` is already in place.
2. **iOS** — the repository declares the Remote notifications background mode.
   In Xcode, enable the Push Notifications signing capability and verify the
   background mode, then upload an APNs authentication key under *Project
   settings → Cloud Messaging*. The signing entitlement and key remain external
   release configuration.
3. **Web** — generate a Web Push VAPID key pair in the same place. The required
   `firebase-messaging-sw.js` worker is in `web/`; pass the public key at build
   time so it is not duplicated in source configuration:

   ```bash
   flutter build web --dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY
   ```

   If registration or token persistence fails, EchoMeet leaves the preference
   disabled instead of claiming that notifications are active.

## Email

Password-reset and verification mail is sent by Firebase Auth itself, from
templates stored in the console rather than in this repository. EchoMeet sends
verification mail during registration and rejects unverified sign-ins. The
proposed wording is in
[email-templates.md](email-templates.md) and has to be pasted in by hand under
*Authentication → Templates*.

Change the sender name and reply-to address at the same time. The default
no-reply on a `firebaseapp.com` domain is the single biggest reason
password-reset mail lands in spam.
