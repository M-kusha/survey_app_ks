# Company directory backfill

This is a one-time release gate for companies created before the public
`companyDirectory` projection existed. Run it locally with short-lived
Application Default Credentials that can read and write Firestore in the
`echomeet-app` project.

The script is read-only unless both the exact project argument and `--apply`
are present. It never updates or deletes a directory document. Before any
write, it reads both collections and aborts if it finds:

- an invalid company name or join policy;
- a directory document with no source company;
- a directory document with extra or missing fields; or
- a name or join-policy mismatch.

A legacy company without `joinPolicy` is projected as `open`, matching the
application and rules fallback. Missing documents are created in atomic batches
of at most 450. Each write uses Firestore `create`, so a document added after
validation causes that batch to fail instead of being overwritten.

## Required release order

Do not run this while companies are being created, renamed, deleted, or having
their join policy changed. Establish a maintenance window first.

1. From the repository root, enter the Functions directory and install the
   locked dependencies if needed:

   ```powershell
   Set-Location .\functions
   npm ci
   ```

2. Authenticate Application Default Credentials using the approved operator
   account. Do not use a downloaded long-lived service-account key.

3. Run the mandatory dry-run. This reads `echomeet-app` but performs no writes:

   ```powershell
   npm run backfill:company-directory -- --project echomeet-app
   ```

4. Review every proposed `CREATE` line. Do not continue unless the summary says
   `conflicts=0`. Resolve invalid, orphaned, or mismatched documents manually,
   then repeat step 3.

5. Apply the reviewed plan with the explicit write flag:

   ```powershell
   npm run backfill:company-directory -- --project echomeet-app --apply
   ```

6. Run the dry-run command from step 3 again. The release gate passes only when
   it reports `create=0 conflicts=0`.

7. Only after that clean verification, return to the repository root and deploy
   the reviewed Firestore rules:

   ```powershell
   Set-Location ..
   firebase deploy --only firestore:rules --project echomeet-app
   ```

8. Release the updated web/mobile clients through their reviewed release
   pipelines. The backfill script does not deploy anything.

If an apply fails after an earlier batch committed, do not edit targets blindly.
Repeat the dry-run: exact documents are skipped, conflicts stop all further
writes, and only still-missing documents are proposed.
