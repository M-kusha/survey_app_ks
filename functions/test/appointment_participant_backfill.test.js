'use strict';

const assert = require('node:assert/strict');
const test = require('node:test');

const {
  EXPECTED_PROJECT,
  parseArgs,
  validateExisting,
} = require('../scripts/backfill_appointment_participants');

test('participant backfill requires the exact production project', () => {
  assert.throws(() => parseArgs([]), /Refusing to run/);
  assert.throws(
    () => parseArgs(['--project', 'another-project']),
    /Refusing to run/,
  );
  assert.deepEqual(parseArgs(['--project', EXPECTED_PROJECT]), {
    apply: false,
    help: false,
    project: EXPECTED_PROJECT,
  });
});

test('participant backfill apply mode is always explicit', () => {
  assert.equal(
    parseArgs(['--project', EXPECTED_PROJECT, '--apply']).apply,
    true,
  );
  assert.throws(
    () => parseArgs(['--project', EXPECTED_PROJECT, '--apply', '--apply']),
    /more than once/,
  );
});

test('participant cache validation accepts only the exact unique user set', () => {
  assert.equal(validateExisting(['bob', 'alice'], ['alice', 'bob']), null);
  assert.match(validateExisting(['alice', 'alice'], ['alice']), /duplicate/);
  assert.match(validateExisting(['alice'], ['alice', 'bob']), /differs/);
  assert.match(validateExisting('alice', ['alice']), /not a string array/);
});
