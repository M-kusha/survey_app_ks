# Security rules tests

Tests for `firestore.rules`, run against the Firebase emulator. Nothing here
touches the real project, so the suite is free to run and safe to run often.

```bash
npm install
npm test
```

## Requirements

- **Java 21 or newer.** The Firebase emulator dropped support for Java below 21.
  Note that the Android build uses Java 17 — if you keep both installed, point
  `JAVA_HOME` at 21 when running these tests.
- Node 18+ (uses the built-in `node:test` runner, so there is no Jest or Vitest
  to install).

## What is covered

33 tests across the parts of the rules that would actually hurt if they were
wrong:

| Area | The question being answered |
|---|---|
| Deny by default | Can an unauthenticated client read or write anything? |
| Company isolation | Can someone at company A see company B's users, surveys, appointments? |
| Role escalation | Can a user promote themselves? Move companies? Promote a colleague? |
| Sign-up | Can a new user join an existing company as superadmin? |
| Survey submissions | **Can a participant rewrite their own score?** |
| Survey authoring | Can a non-admin create, move or delete a survey? |
| Notes | Can a colleague read your private notes? |

The submission tests matter most. Grading runs on the client, so if a
participant could patch their own score document after submitting, the score
would mean nothing at all.

## Reading the output

Failing writes log `PERMISSION_DENIED` to the console. That is the suite working
— most of these tests assert that something is *refused*, and the emulator logs
each refusal. Judge the run by the final `pass`/`fail` counts.
