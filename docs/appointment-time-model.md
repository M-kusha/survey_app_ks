# Appointment time model

EchoMeet stores every appointment slot as an absolute Firestore `Timestamp`.
Each slot has a stable `slotId`, `startAt`, and `endAt`; the parent stores the
creator's IANA `zoneId`, an exact `expirationAt` `Timestamp`, and schema version
2. Offset-less date strings are not part of the canonical schema.

Only the `saveAppointmentDefinition` callable creates or edits temporal
content. It uses server time and accepts a definition only when
`now < expirationAt < earliest startAt`. Client clocks are advisory UI input;
queued votes are accepted or rejected by Firestore `request.time` using the
same strict deadline boundary.

## DST policy

The editor resolves wall-clock input in the creator's named IANA zone. A local
time skipped by a daylight-saving transition is rejected. If the clock repeats
an hour, the editor shows both UTC offsets and requires the creator to choose
one occurrence. Editing an instant creates a new slot ID; an existing slot ID
may not be rebound to another instant.

## Display policy

The app shows the viewer's device-local time first and the creator-zone time,
zone ID, and UTC offset second. Refreshing or resuming after a device-zone
change rebuilds these labels from the stored instant. Push notifications use
the recipient's language but format the instant in the appointment creator's
zone; they never interpolate a raw RFC or English-only timestamp.

This release assumes a clean database. There is no legacy string reader,
dual-write path, or appointment migration script.
