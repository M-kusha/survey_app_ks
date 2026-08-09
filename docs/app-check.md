# Firebase App Check rollout

The client activates App Check before using Auth, Firestore, Storage, or Cloud
Functions. Release Android uses Play Integrity, Apple platforms use App Attest
with DeviceCheck fallback, and web uses reCAPTCHA v3.

Windows is not a production target. FlutterFire currently exposes only its
debug App Check provider there, so a Windows release fails closed at startup
instead of shipping a bypass provider.

## Local development

Debug builds use the platform debug providers. Run the app once, copy the token
printed by the Firebase SDK, and register it under **Firebase Console → App
Check → Manage debug tokens**. A stable token may instead be supplied without
committing it:

```text
--dart-define=FIREBASE_APP_CHECK_DEBUG_TOKEN=<registered-debug-token>
```

Never put that token in source control.

## Web release

Register the web app with a reCAPTCHA v3 provider, then build with its public
site key:

```text
flutter build web --release \
  --dart-define=FIREBASE_APP_CHECK_WEB_KEY=<recaptcha-site-key> \
  --dart-define=FCM_WEB_VAPID_KEY=<vapid-public-key>
```

A release web app fails closed during startup when the App Check site key is
missing. The VAPID value is public configuration, but it is supplied by the
release environment rather than duplicated in the repository.

## Enforcement order

1. Register Android, Apple, and web providers in Firebase Console.
2. Distribute clients containing App Check while enforcement is still off.
3. Monitor valid, invalid, and unknown requests on every supported platform.
4. Resolve old clients and legitimate invalid traffic.
5. Enable enforcement gradually for Firestore, Storage, Authentication, and
   callable Functions.
6. Verify registration, login, notes, surveys, appointments, images, account
   deletion, and notifications on real release builds.

Do not enable enforcement before the updated clients are in use. Console state
and enforcement are external release operations and are not changed by this
repository.
