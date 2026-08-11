# Avatar privacy migration

This migration removes long-lived profile-image download URLs from Firestore
and moves objects from `profile_images/<uid>.jpg` to the UID-addressable,
non-token path `profile_images/<uid>/avatar.jpg`. Updated clients download bytes
through the authenticated Firebase Storage SDK. They can parse legacy Firebase
URLs only to obtain the legacy object reference; they never pass a token URL to
an HTTP image widget. All new writes go through the `uploadProfileImage`
callable; direct client object creation and replacement are denied because the
Firebase upload endpoint can mint a download token after Storage Rules run.

The migration does **not** deploy anything and is read-only unless `--apply` is
present. It accepts only `--project echomeet-app`, hard-codes the exact
`echomeet-app.firebasestorage.app` bucket, and refuses to run when Firestore or
Storage emulator environment variables are set.

## What each phase guarantees

- `access` adds `previousMembership` to existing ban records and atomically
  mirrors a ban into `users/{uid}.membership` and
  `memberDirectory/{uid}.membership` as `pending`. Cloud Storage Rules may read
  at most two Firestore documents in one evaluation. The mirrored state lets
  them check both viewer and owner projections and still reject a banned
  viewer. New ban/unban writes maintain this state atomically.
- `prepare` server-copies each legacy object to the canonical path when needed,
  verifies its GCS checksum, sets private cache metadata, and removes
  `firebaseStorageDownloadTokens` from both old and new objects. It preserves
  the original bytes; it does not claim to remove EXIF from legacy images. The
  App Check and verified-Auth protected callable independently decodes,
  orientation-bakes, metadata-clears, resizes, and JPEG re-encodes every new
  image before its Admin/GCS upload. It derives the canonical path from Auth,
  stores no download token, and atomically updates both profile projections
  with the same monotonic `profileImageRevision`. The callable uses GCS
  generation preconditions and restores the prior object if the Firestore
  synchronization fails, so a reported failure cannot silently publish bytes.
- `switch` changes the private user and same-company member projection in one
  Firestore transaction, initializing or incrementing their shared avatar
  revision. It then changes legacy survey/appointment participant snapshot
  references and revisions in preconditioned batches. Only after re-reading
  the user, member, responses, and token-free destination does it generation-
  condition-delete the legacy object.

Every phase preflights the complete relevant data set and stops before its
first write on invalid references, orphaned objects, projection disagreement,
checksum conflicts, unsynchronized bans, or missing destinations. A failed
apply may have completed earlier independent users; rerun the same dry-run.
Exact records become no-ops and conflicts are never repaired automatically.

## Required rollout order

Use a maintenance/forced-upgrade window. Pause profile changes, survey
submissions, appointment voting, bans/unbans, membership changes, and account or
company deletion. Do not continue while an old mobile client version can still
write avatar URLs or display them directly.

1. Confirm the clean database invariant: every eligible private profile has an
   exact same-UID `memberDirectory` projection and there are no legacy missing
   projections. Stop instead of attempting a backfill if this check fails.
2. Authenticate Application Default Credentials with an approved short-lived
   operator identity. Do not download a service-account key. At minimum, scope
   that identity to Firestore document read/write transactions and object
   list/get/create/update/delete in the one avatar bucket; remove the temporary
   grant after the verified reruns.
3. Install the locked Functions dependencies (`npm ci`) and deploy the reviewed
   Functions **before** applying `access`. This must include the avatar callable
   and the join-request trigger guard that ignores pending membership when the
   same company has a ban document. Without that guard, mirroring an existing
   active member to pending can send a false approval notification. Confirm in
   staging that the callable rejects missing App Check, unverified Auth, and
   malformed, non-JPEG, or oversized payloads.

   ```powershell
   Set-Location .\functions
   npm ci
   npm run build
   Set-Location ..
   firebase deploy --only functions --project echomeet-app
   ```

4. Dry-run and apply the access phase, then repeat its dry-run. The gate is
   `banActions=0 conflicts=0`.

   ```powershell
   Set-Location .\functions
   npm run migrate:avatar-privacy -- --project echomeet-app --phase access
   npm run migrate:avatar-privacy -- --project echomeet-app --phase access --apply
   npm run migrate:avatar-privacy -- --project echomeet-app --phase access
   ```

5. Deploy the reviewed Firestore and Storage rules. Do not release the updated
   client until the previously deployed callable is healthy. Storage rules that
   call
   `firestore.get()` require the Firebase Rules service connection to the
   default Firestore database; accept/verify the IAM setup prompt during the
   controlled rules deployment. Do not enable broad public object ACLs.
6. Confirm the updated web build is live and enforce the minimum updated mobile
   version. Manually verify owner, same-company, cross-company, pending, banned,
   signed-out, and account-deletion-lock cases on the real staging Firebase
   project before touching production avatar objects. Keep the profile,
   user-management, and survey-participant screens open on a second device and
   verify that replacing an avatar refreshes all three without navigation or a
   page reload.
7. Dry-run, review, apply, and rerun `prepare`. Continue only with
   `pendingAvatars=0 conflicts=0` and no `REVOKE_*` or `COPY` lines.

   ```powershell
   npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare
   npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare --apply
   npm run migrate:avatar-privacy -- --project echomeet-app --phase prepare
   ```

8. Run the same dry-run/apply/rerun sequence for `switch`. The final gate is
   `pendingAvatars=0 responseUpdates=0 conflicts=0`; every avatar line must be
   `EXACT`, and a bucket inventory must show no legacy objects or download-token
   metadata.

   ```powershell
   npm run migrate:avatar-privacy -- --project echomeet-app --phase switch
   npm run migrate:avatar-privacy -- --project echomeet-app --phase switch --apply
   npm run migrate:avatar-privacy -- --project echomeet-app --phase switch
   ```

9. Re-enable writes only after the client smoke checks and both Firestore and
   bucket inventories agree. Monitor Storage permission denials, Functions
   account-deletion errors, and Firestore migration conflicts.

## Emulator and staging boundary

The local Storage emulator is useful for syntax, owner/path/content-type, and
basic authorization tests. It is not release proof for production GCS
generation/metageneration preconditions, Firebase download-token revocation,
bucket IAM/public ACL state, or the production Rules-to-Firestore IAM
connection. The migration therefore refuses emulator endpoints. A disposable
staging Firebase project with the same rules and IAM topology is the required
integration check; production is touched only by the reviewed operator-run
dry-runs and applies above.

The Functions runtime identity needs Auth user read, Firestore read/write, and
GCS object get/create/update/delete for the one avatar bucket. The native
`sharp` re-encoder is locked in `functions/package-lock.json`; build and staging
smoke checks must use the supported Node 22 Functions runtime.

The migration was added and locally syntax/unit checked only. It was not run,
and no Firebase project, bucket, or production data was contacted.
