# Notifications

## What costs money

Cloud Functions are not available on the free **Spark** plan. Running them means
switching the project to **Blaze**, which requires a payment method on the
account. That is a change only the project owner can make, in the Firebase
console, and nothing here does it automatically.

The plan is pay-as-you-go with a permanent free allowance, and this app is not
close to it:

| | Free each month | What this app uses |
| --- | --- | --- |
| Function invocations | 2,000,000 | one per survey, meeting, confirmation and join request, plus 2 scheduled runs a day |
| Compute time | 400,000 GB-seconds | a few seconds a day |
| Cloud Messaging | unlimited, always free | all of it |
| Scheduler jobs | 3 free | 2 |

A company creating a survey a day and a couple of meetings a week lands in the
low hundreds of invocations a month against an allowance of two million. Expect
a bill of nothing. Set a budget alert anyway — the console will offer one when
you upgrade, and it costs nothing to say yes.

## Deploying

```bash
firebase deploy --only functions,firestore:indexes --project echomeet-app
```

The indexes matter: two of the queries the functions run are composite and will
fail without them.

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

Tokens rot: apps are uninstalled, browsers are cleared. The sender prunes any
token that comes back permanently invalid, and only those two error codes —
a transient failure must never cost somebody their registration.

## The bit push cannot do

While the app is **open**, the operating system draws nothing at all. That is
not a bug; a foreground message is delivered to the app and it is the app's job
to decide what to do with it. `PushService` shows it through
`flutter_local_notifications`, which is why both packages are needed.

On **web**, foreground notifications are left to the browser and the local
plugin is skipped — `flutter_local_notifications` has no meaningful web
implementation, and drawing our own would be worse than the browser's.

## Before the first send

1. **Android** — nothing. `google-services.json` is already in place.
2. **iOS** — upload an APNs authentication key under *Project settings → Cloud
   Messaging*. Without it, iOS devices register and then silently never receive
   anything, which looks exactly like a broken function.
3. **Web** — generate a VAPID key pair in the same place and pass it to
   `getToken(vapidKey: …)`. Until then web registration fails, which
   `PushService` swallows deliberately: it must never break sign-in.

## Email

Password reset and verification mail is sent by Firebase Auth itself, from
templates stored in the console rather than in this repository. The wording is
in [email-templates.md](email-templates.md) and has to be pasted in by hand
under *Authentication → Templates*.

Change the sender name and reply-to address at the same time. The default
no-reply on a `firebaseapp.com` domain is the single biggest reason
password-reset mail lands in spam.
