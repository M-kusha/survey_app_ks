# Appointment participant-cache backfill

Appointments created by older releases may not contain `participantUserIds`.
The field is now a server-derived display/reminder cache; it is never an
authorization source and clients cannot write it. Current rules keep legacy
appointments editable while this migration is staged.

Run the read-only preflight with Application Default Credentials authorized for
the production project:

```text
cd functions
npm run backfill:appointment-participants -- --project echomeet-app
```

The preflight derives unique user IDs from every appointment's participant
subcollection. It aborts on malformed votes, duplicate or mismatched existing
caches, and never overwrites an existing cache.

Only after the preflight reports `conflicts=0`, run the explicit write mode:

```text
npm run backfill:appointment-participants -- --project echomeet-app --apply
```

The script refuses the emulator so a local dry-run cannot be mistaken for
production evidence. Apply mode re-reads every candidate before its first
write and uses update-time preconditions in batches no larger than 450. A
concurrent vote changes the parent through the trusted trigger, so a stale
migration write fails instead of overwriting current state. Rerun the dry mode
until it reports `backfill=0 conflicts=0` before deploying rules/client changes.

The script was added as a release artifact only. It must not be executed by an
application build or without reviewed production credentials.
