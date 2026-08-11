# EchoMeet production release and migration runbook

This is the operator checklist for the current EchoMeet release. It is a plan,
not an executable script. Nothing in this document proves that a production
backup, migration, deployment, console change, or store release has happened.
Every completed gate needs a named operator, UTC timestamp, command output or
console screenshot, and incident/rollback owner in the release record.

## Fixed production identity

| Item | Required value |
| --- | --- |
| Firebase / Google Cloud project | `echomeet-app` |
| Firestore database | `(default)` |
| Firestore location | `eur3` |
| Functions region | `europe-west4` |
| Avatar bucket | `echomeet-app.firebasestorage.app` |
| Android and iOS bundle ID | `com.echomeet.app` |
| Functions runtime | Node.js 22 |

Pass `--project echomeet-app` on every Firebase or Google Cloud command even
though `.firebaserc` currently has the same default. Stop if a command, ADC
identity, console banner, bucket, database, or function region shows anything
else. Never substitute a staging project into this production checklist and
never treat emulator output as production evidence.

All commands below are run from the repository root unless a step explicitly
enters `functions`. Replace angle-bracket placeholders before use; they are not
literal shell input.

## Current release inventory

### Firebase-controlled files

| File | Release surface |
| --- | --- |
| `firebase.json` | Functions source/predeploy, Firestore rules/indexes, Storage rules, Hosting headers and rewrites |
| `.firebaserc` | Default project; informational only, never a replacement for the explicit project flag |
| `firestore.rules` | Firestore authorization and atomic-write invariants |
| `storage.rules` | Private avatar access and Firestore-backed account/membership checks |
| `firestore.indexes.json` | Three composite indexes and the participant `userId` collection-group field override |
| `functions/package.json` | The only npm command manifest; there is no repository-root `package.json` |
| `pubspec.yaml` / `pubspec.lock` | Flutter build inputs and locked package versions |

### Deployed Functions expected from `functions/src/index.ts`

Every target is v2 and must appear in `europe-west4` after deployment.

| Export | Kind / source |
| --- | --- |
| `completeOnboarding` | Auth + App Check callable; finalizes a verified private onboarding intent |
| `uploadProfileImage` | Auth + App Check callable; sanitizes and stores the caller's avatar |
| `deleteMyAccount` | Recent-Auth + App Check callable; trusted retryable account erasure |
| `saveSurveyDefinition` | Auth + App Check callable; atomically publishes a public survey and its protected answer key |
| `saveAppointmentDefinition` | Auth + App Check callable; creates or revises canonical Timestamp appointment definitions |
| `deleteContent` | Auth + App Check callable; establishes a write barrier and deletes one survey or appointment |
| `onSurveyCreated` | `surveys/{surveyId}` create notification |
| `onSurveyResponseCreated` | trusted initial grading from `surveyAnswerKeys` |
| `onSurveyResponseDeleted` | invalidates live participation state after response deletion |
| `onSurveyResponseUpdated` | trusted regrading after review changes |
| `onAppointmentCreated` | appointment create notification |
| `onAppointmentVoteCreated` | maintains the parent `participantUserIds` cache |
| `onAppointmentVoteDeleted` | removes a voter after their final vote is gone |
| `onTimeSlotConfirmed` | confirmed-time notification |
| `onJoinRequested` | pending-membership transition notification, excluding synchronized bans |
| `onJoinRequestedAtRegistration` | pending profile create notification |
| `remindExpiring` | `0 9 * * *`, `Europe/Berlin` |
| `purgeScheduledCompanies` | `30 3 * * *`, `Europe/Berlin` |
| `purgeAccountDeletionLocks` | `15 * * * *`, UTC |

The supporting modules are `account_deletion.ts`,
`appointment_definition.ts`, `appointment_participants.ts`, `content_deletion.ts`,
`appointment_state.ts`, `join_requests.ts`, `messaging.ts`,
`notification_copy.ts`, `onboarding.ts`, `profile_images.ts`, `purge.ts`,
`scoring.ts`, `survey_publication.ts`, and `trusted_scoring.ts`. They are
compiled through the single
`build` script and are not deployed independently. Server-side image decoding
and re-encoding uses the exact locked `sharp` 0.35.3 dependency.

### Operator scripts in `functions/package.json`

Both commands below exist in the current manifest and point to a present
file under `functions/scripts`. A dry-run still reads production.

| npm command | Script | Clean rerun gate | Ordering dependency |
| --- | --- | --- | --- |
| `backfill:company-directory` | `backfill_company_directory.js` | `create=0 conflicts=0` | before directory-dependent rules/clients |
| `migrate:avatar-privacy` | `migrate_avatar_privacy.js` | phase-specific zero actions/conflicts | member directory + guarded Functions before access; rules/client before prepare/switch |

### Existing focused documents

- `app-check.md`: provider selection and gradual enforcement.
- `appointment-time-model.md`: canonical instants, DST choices, deadlines, and display policy.
- `avatar-privacy-migration.md`: access, prepare, and switch invariants.
- `company-directory-backfill.md`: public company projection.
- `verified-onboarding.md`: verified deferred tenant creation/join.
- `notifications.md`: FCM, region, APNs, VAPID, and scheduled delivery.
- `email-templates.md`: manual Firebase Auth template copy.
- `release-signing.md`: Android and Apple signing gates.
- `legal-release-inputs.md`: operator, store, retention, and deletion-page inputs.

Those documents explain individual changes. This file owns the combined order
when their instructions overlap.

## Gate 0 - release authority and immutable inputs

**[EXTERNAL / MANUAL - release owner]** Do not schedule the production window
until all of these are recorded:

1. One reviewed Git commit and immutable source archive. The tree used to build
   artifacts must match that commit; do not deploy an unclassified dirty tree.
2. Successful, current CI evidence for the reviewed commit, including the
   focused Functions, Firestore Rules, Storage Rules, migration-script, and
   Flutter checks. Do not discover ordinary build/test failures in the
   production window.
3. Versioned Android, iOS, and web artifacts, checksums, release notes, owners,
   and a tested forced-upgrade/minimum-version mechanism for mobile.
4. A named incident commander with access to the previous Functions bundle,
   Firestore ruleset, Storage ruleset, indexes file, Hosting artifact, signed
   mobile artifacts, Firestore export, and Storage recovery mechanism.
5. Blaze billing, budget alerts, quotas, Artifact Registry cleanup policy, and
   Firestore location confirmed by the project owner. The source requires
   `eur3` -> `europe-west4`; do not change the region to work around a deploy
   error.
6. Short-lived Application Default Credentials for the approved operator.
   Long-lived downloaded service-account keys are forbidden.
7. A staging Firebase project with equivalent IAM/rules topology has passed the
   complete migration and device matrix. Emulator success is not proof of GCS
   metadata/generation behavior, APNs, Play Integrity, App Attest, reCAPTCHA,
   VAPID, or Storage-to-Firestore Rules IAM.

From `functions`, install the locked dependency set and produce the reviewed
build before the window:

```powershell
Set-Location .\functions
npm ci
npm run build
Set-Location ..
```

The deploy script also builds, but the earlier build is the artifact gate. Do
not use `npm update`, regenerate a lockfile, or accept package drift during the
release.

## Gate 1 - App Check, signing, push, legal, and artifacts

### App Check provider registration

**[EXTERNAL / MANUAL - Firebase owner]** Register providers before distributing
or deploying a client that calls the three enforced callables:

- Android release: Play Integrity for `com.echomeet.app`, matched to the release
  signing identity.
- iOS release: App Attest with DeviceCheck fallback, matched to the production
  app and distribution identity.
- Web: reCAPTCHA v3 with every production domain allowlisted.

Keep Firestore, Storage, and Authentication App Check console enforcement off
during initial client distribution. `completeOnboarding`,
`uploadProfileImage`, and `deleteMyAccount` set `enforceAppCheck: true` in code,
so their enforcement begins as soon as the new Functions deploy. Debug tokens
belong only to registered development devices and must never enter source,
logs, screenshots, or release artifacts.

### Signed client artifacts

Build web with both public release-time values:

```powershell
flutter build web --release `
  --dart-define=FIREBASE_APP_CHECK_WEB_KEY=<reviewed-recaptcha-v3-site-key> `
  --dart-define=FCM_WEB_VAPID_KEY=<reviewed-public-vapid-key>
```

Build Android only after copying `android/key.properties.example` to the
ignored `android/key.properties` and supplying the real Play upload key:

```powershell
flutter build appbundle --release
```

The Gradle release task deliberately fails when signing values or the keystore
are absent. Verify the AAB certificate fingerprint against Play Console and the
App Check registration before approving it.

Build iOS on the approved macOS/Xcode runner:

```text
flutter build ipa --release
```

**[EXTERNAL / MANUAL - Apple owner]** The repository declares the
`remote-notification` background mode but contains no checked-in Runner
entitlements file. The archive is blocked until its signed entitlements prove
the correct Apple team/profile, production `aps-environment`, Push
Notifications capability, and App Attest capability. Upload and verify the APNs
authentication key in Firebase. Do not infer these from a successful Flutter
compile.

### Web CSP and printing gate

`pubspec.lock` currently pins `printing` **5.15.0**. The Hosting CSP in
`firebase.json` includes the version-specific
`sha256-+M0fGRkOqgYlCQCff9oNQn6k6a7Si4Et8iofLMceadE=` allowance for that
package's injected print helper, and permits the blob frame used for print.
Any `printing` upgrade is a release stop: inspect the generated helper,
recalculate the narrowly scoped SHA-256, review the CSP change, deploy it to
staging, and manually print a real survey PDF under the deployed CSP. Never add
generic inline-script permission as a shortcut.

### Push and email

**[EXTERNAL / MANUAL - messaging owner]** Confirm the APNs key, production iOS
capability, web VAPID key, Android notification permission behavior, and
localized `en`/`de`/`sq` copy. Paste and approve the Firebase Auth verification,
password-reset, and email-change templates from `email-templates.md`, including
a real sender name and reply-to address.

### Legal and public deletion page

**[EXTERNAL / MANUAL - legal/release owner]** Approve the operator/controller
identity, support contact, approved privacy-policy copy, retention/backup statement,
terms if required, Apple App Privacy answers, and Google Play Data Safety
answers and the production origin. After Hosting deployment, verify in a
signed-out browser that the approved origin plus `/privacy-policy/` and
`/account-deletion/` are public, localized, refreshable, navigable, and match
the store listing. Do not infer or prerecord a production hostname from the
Firebase project ID. Source code is not legal approval.

## Gate 2 - enter maintenance and take recoverable backups

**[EXTERNAL / MANUAL - incident commander]** Pause all registrations, company
creation/join/deletion, membership/role/ban changes, avatar changes, survey
creation/submission/review/deletion, appointment creation/edit/voting, and
account deletion. Prevent old mobile clients from writing; hiding only the web
UI is insufficient.

Inventory the currently deployed Functions before changing anything. Pause the
three Scheduler jobs and wait for Firestore/Eventarc work to drain. Record the
exact deployed function revisions and Scheduler job names/states; generated job
names must be discovered in the project, not guessed from this document.

Export the default Firestore database to an approved, access-controlled backup
bucket/prefix and wait for the managed operation to finish successfully:

```powershell
gcloud firestore export "gs://<approved-backup-bucket>/echomeet/<UTC-release-id>" `
  --database="(default)" `
  --project=echomeet-app
```

The release record must contain the export URI, operation ID, completion state,
object manifest, retention policy, and a previously rehearsed restore
procedure. The official managed-export behavior is documented at
<https://firebase.google.com/docs/firestore/manage-data/export-import>.

**[EXTERNAL / MANUAL - Storage owner]** Before avatar `prepare` or `switch`,
prove that `gs://echomeet-app.firebasestorage.app` has an approved recoverable
protection mechanism (for example, retained soft-deleted objects, versioning,
or an immutable verified copy), and capture every avatar object's path,
generation, metageneration, size, checksum, content type, cache control, and
download-token metadata. A Firestore export does not back up Storage objects.
If bucket protection is changed immediately before the release, respect its
documented propagation interval before any copy, token revocation, or deletion.

Also archive the live Firestore/Storage rules releases, index state, Hosting
release, Functions revisions/configuration, App Check enforcement state, Auth
template settings, and push configuration. A local repository copy is not
evidence of what was live.

Stop if the maintenance freeze, completed Firestore export, Storage recovery
evidence, or previous deploy artifacts cannot be proven.

## Gate 3 - production credential and emulator preflight

Enter `functions` once for all operator commands:

```powershell
Set-Location .\functions
```

Before **every** production dry-run or apply, verify that none of these
environment variables is set:

- `FIRESTORE_EMULATOR_HOST`
- `STORAGE_EMULATOR_HOST`
- `FIREBASE_STORAGE_EMULATOR_HOST`
- `FIREBASE_AUTH_EMULATOR_HOST`
- `FUNCTIONS_EMULATOR`

Production modes reject emulator use. Clear the full environment above before
production work. Confirm the ADC principal and its least-privilege, time-bounded Firestore
and Storage access. Every command's output must identify the exact production
project in its header (and the exact avatar bucket where applicable). Stop on
any conflict/quarantine status, unexpected action, authentication fallback, or
project mismatch.

For a partial apply, do not restore individual documents by hand and do not
repeat `--apply` blindly. Preserve its redacted evidence and rerun the same dry
command before deciding how to continue.

## Gate 4 - additive data checks

Run each dry-run, review its complete plan, apply only the approved plan, then
run the identical dry command again. Do not combine or parallelize migrations.

### 4.1 Company directory

```powershell
npm run backfill:company-directory -- --project echomeet-app
npm run backfill:company-directory -- --project echomeet-app --apply
npm run backfill:company-directory -- --project echomeet-app
```

Gate: `create=0 conflicts=0`.

### 4.2 Historic verified-owner and name-lock audit

**[EXTERNAL / MANUAL - security/data owner]** There is no repository script for
this read-only audit. Using an approved, project-pinned Admin SDK procedure,
compare every company owner with Firebase Auth `emailVerified`, and verify every
`companyNames` record and `companyDirectory` projection points to the expected
live company. Review historic unverified owners or malformed locks individually;
do not delete tenants or locks automatically.

The current lock scheme guarantees exact lock-document uniqueness. It does not
provide a migration that makes every accented and ASCII spelling equivalent.
If product policy requires accent-insensitive uniqueness, that policy and a
conflict-reviewed migration are a separate release blocker; do not claim the
current rollout provides it.

Return to the repository root:

```powershell
Set-Location ..
```

## Gate 5 - indexes and the matched backend boundary

### 5.1 Indexes first

```powershell
firebase deploy --only firestore:indexes --project echomeet-app
```

**[EXTERNAL / MANUAL - Firebase owner]** Wait until every index in
`firestore.indexes.json`, including the participant `userId` collection-group
scope, is fully enabled. A successful CLI submission while an index is still
building is not a pass.

### 5.2 Deploy the matched Functions and Firestore rules

Build and deploy the reviewed backend and rules as one release boundary:

```powershell
Set-Location .\functions
npm run deploy
npm run logs
Set-Location ..
firebase deploy --only firestore:rules --project echomeet-app
```

Verify the exact named export inventory above (never a stale numeric count),
immutable revisions, `europe-west4` region, schedules, Eventarc health, and no
unexpected deletion or duplicate. Verify `saveSurveyDefinition` is the only
survey-definition writer, publishes the existing public survey shape and its
schema-version-1 protected answer key in one transaction, and enforces Auth,
App Check, active tenant membership, and staff authorization. Direct client
survey/key creates and updates remain denied. The database is clean, so this
release performs no survey migration or bulk rewrite.

An all-Functions deploy can resume Scheduler jobs; pause all three again until
the smoke gate. Wait for already-delivered Eventarc invocations to drain before
evaluating the new revision.

Also verify `onJoinRequested` includes the company-ban guard before avatar
`access`. Verify company purge preflights name-lock count, performs child/member
cleanup first, and atomically deletes every `companyNames` lock, the
`companyDirectory` projection, and company parent in its final batch. A
different deployed revision is a stop condition.

### 5.3 Avatar access phase

The guarded Functions revision must be live before this phase. Pausing clients
alone does not suppress Firestore triggers.

```powershell
Set-Location .\functions
npm run migrate:avatar-privacy -- --project echomeet-app --phase access
npm run migrate:avatar-privacy -- --project echomeet-app --phase access --apply
npm run migrate:avatar-privacy -- --project echomeet-app --phase access
Set-Location ..
```

Gate: `banActions=0 conflicts=0`, with no join notification caused by the
migration.

## Gate 6 - Storage rules, updated clients, and Hosting

Keep all writes paused for this handover. The rules temporarily make retired
clients unusable; that is acceptable only inside the already-established
forced-upgrade maintenance window.

1. Deploy the same reviewed Firestore and Storage rules together:

   ```powershell
   firebase deploy --only "firestore:rules,storage" --project echomeet-app
   ```

2. Wait for rules propagation and complete the Storage-to-Firestore IAM check
   below. Never edit or publish a different console ruleset during the window;
   a CLI deploy overwrites the console release.
3. **[EXTERNAL / MANUAL - store owners]** Release the already-approved Android
   and iOS artifacts, verify their production App Check attestation, and enforce
   the approved minimum version. Do not continue while an old client can still
   use direct registration, write/display legacy avatar URLs, or depend on
   public answer keys.
4. Deploy the exact reviewed web artifact from `build/web`:

   ```powershell
   firebase deploy --only hosting --project echomeet-app
   ```

5. In a clean signed-out browser and a verified test account, confirm the
   deployed web build receives App Check, registers FCM with the release VAPID
   key, does not serve a stale service worker, and reaches the new Functions.

6. Keep client writes frozen until the signed-out and authenticated web/mobile
   smoke checks pass against the deployed Functions and rules.

### Storage-to-Firestore IAM gate

`storage.rules` calls `firestore.exists()` for account-deletion locks and
`firestore.get()` for member projections. During the controlled Storage rules
deployment, accept/verify the Firebase prompt that connects Rules to the
default Firestore database. In Google Cloud IAM (including Google-provided role
grants), verify the Firebase Storage service account ending in
`@gcp-sa-firebasestorage.iam.gserviceaccount.com` has the **Firebase Rules
Firestore Service Agent** role. The official cross-service behavior and prompt
are documented at
<https://firebase.google.com/docs/storage/security/rules-conditions> and
<https://firebase.google.com/docs/rules/manage-deploy>.

Use a dedicated real release test account to prove all three paths against the
deployed services:

- an allowed same-company authenticated avatar read succeeds;
- a cross-company/banned read is denied;
- with an Admin-created account-deletion lock, callable avatar upload and the
  owner Storage operation guarded by `accountActive()` are denied.

Also confirm direct client avatar create/update remains denied because uploads
must go through `uploadProfileImage`. The local Storage emulator cannot certify
the production cross-service IAM connection.

## Gate 7 - avatar object prepare and irreversible switch

Do not start until the updated Functions, minimum client version, Firestore
rules, Storage rules, cross-service IAM, and real-device avatar smoke tests all
pass.

### 7.1 Prepare canonical objects and revoke bearer tokens

```powershell
Set-Location .\functions
npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare
npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare --apply
npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare
```

Gate: `pendingAvatars=0 conflicts=0` with no `COPY`, `REVOKE_LEGACY`, or
`REVOKE_NEW` lines. This is a rollback boundary: old clients that render token
URLs may stop working after token revocation even though Firestore references
have not switched yet.

### 7.2 Switch references and delete legacy objects

```powershell
npm run migrate:avatar-privacy -- --project echomeet-app --phase switch
npm run migrate:avatar-privacy -- --project echomeet-app --phase switch --apply
npm run migrate:avatar-privacy -- --project echomeet-app --phase switch
Set-Location ..
```

Gate: `pendingAvatars=0 responseUpdates=0 conflicts=0`; every avatar line is
`EXACT`; the bucket inventory contains no legacy avatar objects or download
token metadata. After this boundary, rolling back only code or rules is unsafe;
old paths and bearer-token assumptions are gone.

## Gate 8 - global clean rerun

Still under maintenance, repeat every dry-run without `--apply` and attach all
outputs to the release record:

```powershell
Set-Location .\functions
npm run backfill:company-directory -- --project echomeet-app
npm run migrate:avatar-privacy -- --project echomeet-app --phase access
npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare
npm run migrate:avatar-privacy -- --project echomeet-app --phase switch
Set-Location ..
```

Every phase must meet its documented zero-action, zero-conflict gate. Any new
work means the freeze was ineffective or state changed unexpectedly; stop and
investigate.

## Gate 9 - production smoke matrix and maintenance exit

Use dedicated non-customer test tenants/accounts and inspect Function logs,
Firestore, Storage metadata, and visible client state after each action.
| Surface | Required production check |
| --- | --- |
| Registration | verification email; no pre-verification company/name lock; verified create/join resumes after app close, login, and web refresh; conflict retry works |
| Session/state | web route refresh and mobile restart retain the correct verified tenant/session state without requiring a manual refresh |
| Directory/membership | public company listing contains only projection fields; member directory contains no private email/birthdate/token data; join/approve/ban/unban/remove behavior is correct |
| Notes | save appears on another device; a stale local draft never auto-overwrites newer cloud text; explicit local/cloud recovery works; delete/Undo survives close/reload and leaves no one-sided row/body |
| Surveys/tests | create private key atomically; participants cannot read it; initial score and review score are server-authored; no `trusted survey scoring failed closed` or review equivalent |
| Appointments | legacy/future deadlines work; create/vote/delete maintains `participantUserIds`; reminders use authoritative votes; confirmation notifies once |
| Avatars | sanitized upload callable; owner/same-company display; cross-company/pending/banned/signed-out denial; no token URL/path leakage; deletion-lock denial |
| Account deletion | recent-login gate, retry behavior, non-owner deletion, owner warning/company destruction path, Auth removal last, and lock cleanup |
| Push | Android/iOS/web permission and registration; foreground, background, tap, and cold-start routing; locale; invalid-token pruning; no false join notifications from the avatar migration |
| App Check | valid attestation on web, Android, and iOS; no debug provider/token in release; callable rejection without valid token |
| Web CSP | reCAPTCHA/App Check, FCM worker, PDF preview, and an actual print from the deployed origin; no CSP violations |
| Public/legal | approved-origin `/privacy-policy/` and `/account-deletion/` signed-out URLs, privacy/terms/support links where approved, store declarations, and approved operator details |

Review logs for account-deletion failures, operator-script conflicts, Storage
permission anomalies, App Check invalid/unknown traffic, Eventarc retries,
scoring fail-closed messages, and duplicate/missing notifications. Resume the
three Scheduler jobs and verify their next-run times. Re-enable user writes in
one controlled step only after every owner signs the release record.

## Gate 10 - gradual App Check console enforcement

**[EXTERNAL / MANUAL - Firebase owner]** Do this after updated clients are in
use, not during the backend/rules handover:

1. Monitor App Check valid, invalid, and unknown request metrics separately for
   web, Android, and iOS while Firestore/Storage/Auth enforcement remains off.
2. Account for a full real release cohort, old versions, background push opens,
   email-link flows, and supported OS/device combinations. Resolve every
   legitimate invalid/unknown source.
3. Enable Firestore enforcement, run the full smoke subset, and monitor before
   continuing.
4. Enable Storage enforcement, repeat avatar and account-deletion-lock checks,
   and monitor.
5. Enable Authentication enforcement last; repeat registration, verification,
   login, reset, email-link, and session-refresh checks.
6. Record the console state and time for each product. Callable enforcement is
   already code-controlled and must remain verified.

If legitimate traffic is rejected, disable enforcement only for the affected
product, capture metrics/logs, and investigate. Do not distribute a debug token
or weaken application/rules authorization as an App Check workaround. Current
monitoring guidance is at
<https://firebase.google.com/docs/app-check/monitor-metrics>.

## Rollback and stop boundaries

Rollback always uses the previous reviewed artifact set and the explicit
`echomeet-app` project. Never mix a previous client with current rules or a
previous function with the current data schema without checking the boundary
below.

| Last completed boundary | Safe response |
| --- | --- |
| Dry-run only | Fix conflicts or abandon the release; production data is unchanged by the script |
| Directory/expiration/participant backfills | Leave exact additive fields/projections in place; redeploying old clients does not require deleting them |
| Avatar `access` complete | Leave synchronized ban fields unless a reviewed ban-state rollback exists; verify membership and notifications before any code rollback |
| Firestore/Storage rules deployed | A rules-only rollback can reopen fixed vulnerabilities or violate current clients. Redeploy the matched previous Functions/rules/client set or roll forward |
| Avatar `prepare` complete | Download tokens are revoked. Do not release an old URL-rendering client; roll forward or use the rehearsed object/metadata recovery plan |
| Avatar `switch` complete | Legacy objects/references are removed. Code-only rollback is prohibited; roll forward or invoke the approved Firestore + Storage generation-aware data recovery plan |
| Hosting deployed | Redeploy the previous immutable Hosting artifact and verify service-worker/cache behavior; mobile releases cannot be recalled the same way |
| App Check product enforced | Disable only the affected product's console enforcement if valid users are blocked; preserve other authorization controls |

For any partially committed operator script, the first recovery action is its same
dry-run, not a broad Firestore import. A full import can overwrite valid
post-export state and requires incident-commander approval, a renewed write
freeze, and the rehearsed restore plan. Never delete private answer keys,
directory projections, canonical avatar objects, or account-deletion locks just
to make a rollback appear clean.

Rollback completion requires the same smoke matrix, log review, Scheduler-state
verification, public deletion-page check, and recorded owner sign-off as the
forward release.

## Known contradictions and external blockers in this checkout

These must be resolved or explicitly accepted in the release record:

1. The repository's iOS background mode is present, but production signing,
   `aps-environment`, Push Notifications, and App Attest entitlements are
   external and are not proven by a checked-in Runner entitlements file.
2. Avatar `access` can look like a join request to an older
   `onJoinRequested` trigger. The current tree contains a company-ban guard,
   which is why Gate 5 requires the new Functions revision to be live and
   verified before the access phase.
3. Restrictive onboarding/directory/rules changes deny the retired direct
   registration flow. A backend deploy alone is not a mobile rollout plan;
   minimum-version enforcement and old-client retirement are external gates.
4. Firebase Console state (App Check enforcement, Auth templates, APNs/VAPID,
   IAM, legal/store data, billing, deployed rules/functions, and backups) cannot
   be proven from this repository and must be captured manually.
5. No checked-in operator script audits historic owner email verification or
   canonicalizes accent-equivalent legacy company-name locks. Gate 4.6 is a
   manual security/data-owner decision, not evidence that such cleanup ran.

Do not reinterpret an unresolved item as permission to skip a migration,
weaken a rule, reintroduce public answer keys/token URLs, or deploy with the
wrong project.
