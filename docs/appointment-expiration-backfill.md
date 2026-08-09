# Appointment expiration backfill

This is a one-time release gate for future appointments created before
`expirationAt` was added. The old `expirationDate` value is an ISO string; the
new timestamp is what security rules and reminder queries use to enforce the
voting deadline.

The script is read-only by default. It requires the exact Firebase project
argument and only writes when `--apply` is also supplied. It skips expired
legacy appointments and deadlines within five minutes, never overwrites an
existing `expirationAt`, validates every candidate before the first write, and
writes at most 450 documents per batch with update-time preconditions.

## Timezone decision

An ISO value ending in `Z` or a numeric offset is unambiguous. Older EchoMeet
values may have no timezone because Dart serialized a local `DateTime`. The
script deliberately refuses to guess what timezone those values meant.

Determine the intended IANA timezone from production provenance before using
`--assume-time-zone`. Do not choose `Europe/Berlin` merely because the current
operator is in that timezone. A nonexistent local time in a DST gap or an
ambiguous time in a DST fold is reported as a conflict and must be resolved
manually.

## Required release order

1. Establish a maintenance window for appointment editing and creation.
2. From `functions`, install the locked dependencies if needed and authenticate
   Application Default Credentials with the approved operator account. Do not
   download or commit a long-lived service-account key.
3. Run the mandatory dry-run:

   ```powershell
   npm run backfill:appointment-expiration -- --project echomeet-app
   ```

4. If timezone-less values are reported, first establish their intended zone,
   then repeat the dry-run with an explicit IANA value, for example:

   ```powershell
   npm run backfill:appointment-expiration -- --project echomeet-app --assume-time-zone Europe/Berlin
   ```

5. Do not continue while any validation conflict remains. Review the eligible
   count and resolve malformed, ambiguous, or nonexistent dates manually.
6. Re-run the reviewed command with `--apply` appended. For example:

   ```powershell
   npm run backfill:appointment-expiration -- --project echomeet-app --assume-time-zone Europe/Berlin --apply
   ```

7. Run the same command again without `--apply`. The release gate passes only
   when it reports no conflicts and no eligible future legacy documents.
8. Complete the company-directory backfill, then deploy the reviewed rules,
   indexes, Functions, and clients using the pinned `echomeet-app` project.

The script is safe to rerun after partial progress. If a later batch loses an
update-time race, earlier batches can already be committed; the next dry-run
skips exact completed records and reports whatever still requires attention.
The script never deploys code or configuration.
