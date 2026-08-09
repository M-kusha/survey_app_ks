# Private survey answer-key migration

This is a required two-phase release gate for surveys created before grading
keys were separated from member-readable survey documents. It uses Application
Default Credentials against the exact `echomeet-app` project. The script is
read-only unless `--apply` is also present; it never prints answer values.

The phases are deliberately separate:

- `prepare` creates `surveyAnswerKeys/{surveyId}` with Firestore `create` and
  leaves the current public survey content unchanged. The same batch performs
  a preconditioned same-value source write so a concurrent survey change or
  deletion makes the batch fail rather than creating an orphan. It aborts if a test has an
  incomplete key, a private key is orphaned, or existing public/private keys
  disagree.
- `sanitize` requires and validates an exact private key first, then removes
  `correctAnswer` and `correctAnswers` from the public question maps using an
  update-time precondition. It never creates or repairs a key.

Both phases preflight the entire data set before their first write, use batches
of at most 450 operations, and are safe to rerun. A failed apply can leave
earlier batches committed; repeat the same dry run to identify only the
remaining work. Do not edit conflicts automatically.

## Required release order

Use a maintenance window that prevents survey creation, submissions, reviews,
and deletion for the whole sequence. The old scorer needs public keys while the
new scorer needs private keys, so the maintenance gate is what prevents a
response from being graded during the handover.

1. From the repository root, install the locked Functions dependencies if
   needed:

   ```powershell
   Set-Location .\functions
   npm ci
   ```

2. Authenticate Application Default Credentials with the approved short-lived
   operator account. Do not download or commit a service-account key.

3. Dry-run the prepare phase:

   ```powershell
   npm run migrate:survey-answer-keys -- --project echomeet-app --phase prepare
   ```

4. Review every `CREATE_KEY` identifier. Continue only with `conflicts=0`, then
   apply and repeat the dry run until it reports `actions=0 conflicts=0`:

   ```powershell
   npm run migrate:survey-answer-keys -- --project echomeet-app --phase prepare --apply
   npm run migrate:survey-answer-keys -- --project echomeet-app --phase prepare
   ```

5. Deploy the reviewed Functions while the maintenance window remains active.
   Confirm the deployed grading triggers are the version that reads
   `surveyAnswerKeys` and fails closed on a missing/mismatched key.

6. Dry-run, review, apply, and recheck the sanitize phase:

   ```powershell
   npm run migrate:survey-answer-keys -- --project echomeet-app --phase sanitize
   npm run migrate:survey-answer-keys -- --project echomeet-app --phase sanitize --apply
   npm run migrate:survey-answer-keys -- --project echomeet-app --phase sanitize
   ```

   The release gate passes only at `actions=0 conflicts=0`.

7. Deploy the reviewed Firestore rules and release the updated clients. New
   clients create/delete the public survey and private key atomically; clients
   can never read or update the private collection.

8. Re-enable survey activity and monitor Function errors for
   `trusted survey scoring failed closed` or `survey review scoring failed
   closed`. Treat either as a release incident; never copy keys back into the
   public survey as a workaround.

The migration was added and syntax-checked only. It was not executed, and no
Firebase project or production data was contacted by this audit.
