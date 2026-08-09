#!/usr/bin/env node
'use strict';

const { applicationDefault, initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const EXPECTED_PROJECT = 'echomeet-app';
const COLLECTION = 'appointments';
const WRITE_BATCH_LIMIT = 450;
const FUTURE_GUARD_MS = 5 * 60 * 1000;
const REPORT_LIMIT = 100;
const ISO_DATE_TIME =
  /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?(Z|[+-]\d{2}:\d{2})?$/;

class UsageError extends Error {}

function usage() {
  return `Usage:
  node scripts/backfill_appointment_expiration.js \\
    --project ${EXPECTED_PROJECT} [--assume-time-zone <IANA>] [--apply]

Safety:
  * The default is a dry run. It reads and reports but never writes.
  * Writes require BOTH the exact flag "--project ${EXPECTED_PROJECT}" and
    "--apply". Every mode refuses a Firestore emulator so a release dry-run
    cannot accidentally validate an empty local database.
  * Legacy ISO strings with Z or a numeric offset are unambiguous.
  * A timezone-less legacy string is a conflict unless the operator explicitly
    supplies --assume-time-zone. The zone must come from production provenance;
    this script never guesses one.
  * Ambiguous or nonexistent local times at DST transitions are conflicts.
  * Any validation conflict aborts the whole preflight before the first write.
  * Deadlines within five minutes are skipped so a value is not expected to
    expire while its network commit is in flight.
  * Apply writes use update-time preconditions in batches of at most
    ${WRITE_BATCH_LIMIT}. Rerunning is safe: existing expirationAt values are not overwritten.`;
}

function parseArgs(argv) {
  const options = {
    apply: false,
    assumeTimeZone: null,
    help: false,
    project: null,
  };

  function takeValue(index, flag) {
    const value = argv[index + 1];
    if (!value || value.startsWith('--')) {
      throw new UsageError(`${flag} requires a value.`);
    }
    return value;
  }

  for (let index = 0; index < argv.length; index += 1) {
    const argument = argv[index];
    if (argument === '--help' || argument === '-h') {
      options.help = true;
    } else if (argument === '--apply') {
      if (options.apply) throw new UsageError('--apply was supplied more than once.');
      options.apply = true;
    } else if (argument === '--project') {
      if (options.project !== null) {
        throw new UsageError('--project was supplied more than once.');
      }
      options.project = takeValue(index, '--project');
      index += 1;
    } else if (argument.startsWith('--project=')) {
      if (options.project !== null) {
        throw new UsageError('--project was supplied more than once.');
      }
      options.project = argument.slice('--project='.length);
    } else if (argument === '--assume-time-zone') {
      if (options.assumeTimeZone !== null) {
        throw new UsageError('--assume-time-zone was supplied more than once.');
      }
      options.assumeTimeZone = takeValue(index, '--assume-time-zone');
      index += 1;
    } else if (argument.startsWith('--assume-time-zone=')) {
      if (options.assumeTimeZone !== null) {
        throw new UsageError('--assume-time-zone was supplied more than once.');
      }
      options.assumeTimeZone = argument.slice('--assume-time-zone='.length);
    } else {
      throw new UsageError(`Unknown argument: ${argument}`);
    }
  }

  if (!options.help && options.project !== EXPECTED_PROJECT) {
    throw new UsageError(
      `Refusing to continue: --project must be exactly "${EXPECTED_PROJECT}".`,
    );
  }
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    throw new UsageError(
      'Refusing while FIRESTORE_EMULATOR_HOST is set. Clear it before a release dry-run or apply.',
    );
  }

  return options;
}

function makeZoneContext(timeZone) {
  if (!timeZone) return null;

  let formatter;
  try {
    formatter = new Intl.DateTimeFormat('en-CA', {
      calendar: 'iso8601',
      day: '2-digit',
      fractionalSecondDigits: 3,
      hour: '2-digit',
      hourCycle: 'h23',
      minute: '2-digit',
      month: '2-digit',
      numberingSystem: 'latn',
      second: '2-digit',
      timeZone,
      year: 'numeric',
    });
    formatter.format(new Date());
  } catch (error) {
    throw new UsageError(
      `Invalid IANA time zone "${timeZone}": ${error.message}`,
    );
  }

  return { formatter, offsetsByDay: new Map(), timeZone };
}

function utcMillis(parts) {
  const date = new Date(0);
  date.setUTCFullYear(parts.year, parts.month - 1, parts.day);
  date.setUTCHours(
    parts.hour,
    parts.minute,
    parts.second,
    parts.millisecond,
  );
  return date.getTime();
}

function validCalendarParts(parts) {
  if (
    parts.year < 1 ||
    parts.month < 1 ||
    parts.month > 12 ||
    parts.day < 1 ||
    parts.day > 31 ||
    parts.hour < 0 ||
    parts.hour > 23 ||
    parts.minute < 0 ||
    parts.minute > 59 ||
    parts.second < 0 ||
    parts.second > 59
  ) {
    return false;
  }

  const date = new Date(utcMillis(parts));
  return (
    date.getUTCFullYear() === parts.year &&
    date.getUTCMonth() + 1 === parts.month &&
    date.getUTCDate() === parts.day &&
    date.getUTCHours() === parts.hour &&
    date.getUTCMinutes() === parts.minute &&
    date.getUTCSeconds() === parts.second &&
    date.getUTCMilliseconds() === parts.millisecond
  );
}

function wallParts(formatter, milliseconds) {
  const values = {};
  for (const part of formatter.formatToParts(new Date(milliseconds))) {
    if (part.type !== 'literal') values[part.type] = Number(part.value);
  }
  return {
    day: values.day,
    hour: values.hour,
    millisecond: values.fractionalSecond ?? 0,
    minute: values.minute,
    month: values.month,
    second: values.second,
    year: values.year,
  };
}

function sameWallTime(left, right) {
  return (
    left.year === right.year &&
    left.month === right.month &&
    left.day === right.day &&
    left.hour === right.hour &&
    left.minute === right.minute &&
    left.second === right.second &&
    left.millisecond === right.millisecond
  );
}

function possibleOffsets(zoneContext, parts) {
  const cacheKey = [parts.year, parts.month, parts.day].join('-');
  const cached = zoneContext.offsetsByDay.get(cacheKey);
  if (cached) return cached;

  const nominal = utcMillis({ ...parts, hour: 12, minute: 0, second: 0 });
  const offsets = new Set();
  const threeHours = 3 * 60 * 60 * 1000;
  const twoDays = 2 * 24 * 60 * 60 * 1000;

  // Sampling both sides of the local day captures the offsets before and after
  // a transition. Candidate instants are then round-tripped below, which is
  // what detects gaps (zero matches) and folds (two matches).
  for (let delta = -twoDays; delta <= twoDays; delta += threeHours) {
    const instant = Math.floor((nominal + delta) / 1000) * 1000;
    const shownAsUtc = utcMillis(wallParts(zoneContext.formatter, instant));
    offsets.add(shownAsUtc - instant);
  }

  const result = [...offsets];
  zoneContext.offsetsByDay.set(cacheKey, result);
  return result;
}

function resolveLocalTime(parts, nanoseconds, zoneContext) {
  const nominal = utcMillis(parts);
  const matches = new Set();

  for (const offset of possibleOffsets(zoneContext, parts)) {
    const candidate = nominal - offset;
    if (sameWallTime(wallParts(zoneContext.formatter, candidate), parts)) {
      matches.add(candidate);
    }
  }

  if (matches.size === 0) {
    return {
      error: `nonexistent local time in ${zoneContext.timeZone} (DST gap)`,
    };
  }
  if (matches.size > 1) {
    return {
      error: `ambiguous local time in ${zoneContext.timeZone} (DST fold)`,
    };
  }

  const milliseconds = [...matches][0];
  return {
    timestamp: new Timestamp(Math.floor(milliseconds / 1000), nanoseconds),
  };
}

function parseExpirationDate(value, zoneContext) {
  if (typeof value !== 'string') {
    return { error: 'expirationDate is not a string' };
  }

  const match = ISO_DATE_TIME.exec(value);
  if (!match) {
    return { error: 'expirationDate is not a strict ISO date-time' };
  }

  const fraction = match[7] ?? '';
  const nanoseconds = Number(fraction.padEnd(9, '0'));
  const parts = {
    day: Number(match[3]),
    hour: Number(match[4]),
    millisecond: Number(fraction.padEnd(3, '0').slice(0, 3)),
    minute: Number(match[5]),
    month: Number(match[2]),
    second: Number(match[6]),
    year: Number(match[1]),
  };
  if (!validCalendarParts(parts)) {
    return { error: 'expirationDate contains an invalid calendar date or time' };
  }

  const offset = match[8];
  if (!offset) {
    if (!zoneContext) {
      return {
        error:
          'timezone-less expirationDate requires explicit --assume-time-zone',
      };
    }
    return resolveLocalTime(parts, nanoseconds, zoneContext);
  }

  if (offset === '-00:00') {
    return { error: 'expirationDate uses the unknown offset -00:00' };
  }
  if (offset !== 'Z') {
    const offsetHour = Number(offset.slice(1, 3));
    const offsetMinute = Number(offset.slice(4, 6));
    if (
      offsetHour > 14 ||
      offsetMinute > 59 ||
      (offsetHour === 14 && offsetMinute !== 0)
    ) {
      return { error: 'expirationDate contains an invalid UTC offset' };
    }
  }

  const secondsOnly = value.replace(/\.\d{1,9}(?=Z|[+-]\d{2}:\d{2}$)/, '');
  const milliseconds = Date.parse(secondsOnly);
  if (!Number.isFinite(milliseconds)) {
    return { error: 'expirationDate could not be converted to an instant' };
  }

  return {
    timestamp: new Timestamp(Math.floor(milliseconds / 1000), nanoseconds),
  };
}

function timestampsEqual(left, right) {
  return (
    left.seconds === right.seconds && left.nanoseconds === right.nanoseconds
  );
}

function reportEntries(label, entries) {
  if (entries.length === 0) return;
  console.error(`${label} (${entries.length}):`);
  for (const entry of entries.slice(0, REPORT_LIMIT)) {
    console.error(`  - ${entry.path}: ${entry.reason}`);
  }
  if (entries.length > REPORT_LIMIT) {
    console.error(`  ... ${entries.length - REPORT_LIMIT} more not printed`);
  }
}

function chunks(values, size) {
  const result = [];
  for (let start = 0; start < values.length; start += size) {
    result.push(values.slice(start, start + size));
  }
  return result;
}

async function preflight(db, zoneContext) {
  const scannedAt = Timestamp.now();
  const snapshot = await db.collection(COLLECTION).get();
  const candidates = [];
  const conflicts = [];
  let alreadyPresent = 0;
  let expiredLegacy = 0;

  for (const document of snapshot.docs) {
    const data = document.data();
    const hasExpirationAt = Object.prototype.hasOwnProperty.call(
      data,
      'expirationAt',
    );

    if (hasExpirationAt) {
      if (data.expirationAt instanceof Timestamp) {
        alreadyPresent += 1;
      } else {
        conflicts.push({
          path: document.ref.path,
          reason: 'expirationAt exists but is not a Firestore Timestamp',
        });
      }
      continue;
    }

    const parsed = parseExpirationDate(data.expirationDate, zoneContext);
    if (parsed.error) {
      conflicts.push({ path: document.ref.path, reason: parsed.error });
      continue;
    }
    if (
      parsed.timestamp.toMillis() <=
      scannedAt.toMillis() + FUTURE_GUARD_MS
    ) {
      expiredLegacy += 1;
      continue;
    }

    candidates.push({
      expirationAt: parsed.timestamp,
      expirationDate: data.expirationDate,
      path: document.ref.path,
      ref: document.ref,
      updateTime: document.updateTime,
    });
  }

  return {
    alreadyPresent,
    candidates,
    conflicts,
    expiredLegacy,
    scanned: snapshot.size,
    scannedAt,
  };
}

async function revalidateBeforeWrite(db, candidates) {
  const conflicts = [];
  const ready = [];
  let completedElsewhere = 0;

  for (const group of chunks(candidates, WRITE_BATCH_LIMIT)) {
    const snapshots = await db.getAll(...group.map((candidate) => candidate.ref));
    const byPath = new Map(group.map((candidate) => [candidate.path, candidate]));

    for (const document of snapshots) {
      const candidate = byPath.get(document.ref.path);
      if (!candidate || !document.exists) {
        conflicts.push({
          path: candidate?.path ?? document.ref.path,
          reason: 'document disappeared after preflight',
        });
        continue;
      }

      const data = document.data();
      if (data.expirationDate !== candidate.expirationDate) {
        conflicts.push({
          path: candidate.path,
          reason: 'expirationDate changed after preflight',
        });
        continue;
      }

      if (Object.prototype.hasOwnProperty.call(data, 'expirationAt')) {
        if (
          data.expirationAt instanceof Timestamp &&
          timestampsEqual(data.expirationAt, candidate.expirationAt)
        ) {
          completedElsewhere += 1;
        } else {
          conflicts.push({
            path: candidate.path,
            reason: 'a conflicting expirationAt appeared after preflight',
          });
        }
        continue;
      }

      ready.push({ ...candidate, updateTime: document.updateTime });
    }
  }

  return { completedElsewhere, conflicts, ready };
}

async function applyBackfill(db, candidates) {
  let expiredDuringRun = 0;
  let written = 0;

  for (const group of chunks(candidates, WRITE_BATCH_LIMIT)) {
    const now = Date.now();
    const future = group.filter((candidate) => {
      const keep =
        candidate.expirationAt.toMillis() > now + FUTURE_GUARD_MS;
      if (!keep) expiredDuringRun += 1;
      return keep;
    });
    if (future.length === 0) continue;

    const batch = db.batch();
    for (const candidate of future) {
      batch.update(
        candidate.ref,
        { expirationAt: candidate.expirationAt },
        { lastUpdateTime: candidate.updateTime },
      );
    }
    await batch.commit();
    written += future.length;
    console.log(`Committed ${future.length} document(s); total written: ${written}.`);
  }

  return { expiredDuringRun, written };
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  if (options.help) {
    console.log(usage());
    return;
  }

  const zoneContext = makeZoneContext(options.assumeTimeZone);
  const mode = options.apply ? 'APPLY' : 'DRY RUN';
  console.log(`Mode: ${mode}`);
  console.log(`Project: ${options.project}`);
  console.log(
    `Timezone-less values: ${
      zoneContext ? `explicitly interpreted as ${zoneContext.timeZone}` : 'rejected'
    }`,
  );

  const app = initializeApp({
    credential: applicationDefault(),
    projectId: options.project,
  });
  const db = getFirestore(app);
  const result = await preflight(db, zoneContext);

  console.log(`Scanned appointments: ${result.scanned}`);
  console.log(`Already have Timestamp expirationAt: ${result.alreadyPresent}`);
  console.log(
    `Expired/within-five-minutes legacy documents skipped: ${result.expiredLegacy}`,
  );
  console.log(`Future legacy documents eligible: ${result.candidates.length}`);
  console.log(`Validation conflicts: ${result.conflicts.length}`);
  reportEntries('Conflicts', result.conflicts);

  if (result.conflicts.length > 0) {
    throw new Error('Preflight failed; no writes were attempted.');
  }
  if (!options.apply) {
    console.log('Dry run complete; no writes were attempted.');
    return;
  }
  if (result.candidates.length === 0) {
    console.log('Nothing to backfill.');
    return;
  }

  // Re-read every candidate before the first commit. This catches a competing
  // migration or edit after the scan; per-write update-time preconditions close
  // the remaining race without overwriting newer data.
  const revalidated = await revalidateBeforeWrite(db, result.candidates);
  reportEntries('Conflicts after revalidation', revalidated.conflicts);
  if (revalidated.conflicts.length > 0) {
    throw new Error('Revalidation failed; no writes were attempted.');
  }

  console.log(`Completed concurrently and skipped: ${revalidated.completedElsewhere}`);
  const applied = await applyBackfill(db, revalidated.ready);
  console.log(`Expired during this run and skipped: ${applied.expiredDuringRun}`);
  console.log(`Backfilled successfully: ${applied.written}`);
}

main().catch((error) => {
  if (error instanceof UsageError) {
    console.error(error.message);
    console.error(usage());
    process.exitCode = 64;
    return;
  }
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
});
