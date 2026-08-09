# Member directory backfill

This is a mandatory release gate for profiles created before the private
`users/{uid}` documents were separated from the company-visible
`memberDirectory/{uid}` projection.

The projection contains only `fullName`, optional `profileImage`, optional
server-owned `profileImageRevision`, `companyId`, `role`, and `membership`. It
never copies email, birth date, FCM tokens, locale, or other private account
data.

After this backfill reaches zero conflicts, the separate
`avatar-privacy-migration.md` gate replaces any legacy `profileImage` download
URL with an authenticated Storage object path.

The script is read-only unless both the exact `echomeet-app` project argument
and `--apply` are present. It creates missing projections only; it never updates
or deletes data. Before any write, it reads `users`, `companies`, and
`memberDirectory` and aborts on:

- a user that references a missing company;
- invalid name, role, membership, or profile-image data;
- a projection with no source user or a source user with no company;
- extra or missing projection fields; or
- any value that differs from the private source profile.

Legacy users without a `membership` field are projected as `active`, matching
the application and security-rule fallback. Creates use Firestore `create` in
batches of at most 450, so a concurrent target creation makes the batch fail
instead of being overwritten.

## Required release order

Use a maintenance window in which registrations, profile-image changes,
membership approvals, role changes, joins, removals, and company deletion are
paused.

1. Install the locked Functions dependencies if needed:

   ```powershell
   Set-Location .\functions
   npm ci
   ```

2. Authenticate Application Default Credentials using the approved operator
   account. Do not download or store a long-lived service-account key.

3. Run the mandatory dry-run. It reads production but performs no writes:

   ```powershell
   npm run backfill:member-directory -- --project echomeet-app
   ```

4. Review every `CREATE` line. Continue only when `conflicts=0`. Resolve every
   invalid, orphaned, or mismatched record and repeat the dry-run.

5. Apply the reviewed create-only plan:

   ```powershell
   npm run backfill:member-directory -- --project echomeet-app --apply
   ```

6. Repeat the dry-run. This gate passes only with `create=0 conflicts=0`.

7. Deploy the reviewed Functions and rules before releasing a client that uses
   `memberDirectory`:

   ```powershell
   Set-Location ..
   firebase deploy --only functions,firestore:rules --project echomeet-app
   ```

8. Release the reviewed web/mobile clients. The script itself deploys nothing.

If apply stops after an earlier batch committed, run the dry-run again. Exact
documents are skipped, conflicts stop further writes, and only missing targets
are proposed.
