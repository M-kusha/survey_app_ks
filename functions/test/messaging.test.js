const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const { verifiedEnabledAuthIds } = require('../lib/messaging');

const ids = Array.from({ length: 205 }, (_, index) => `user-${index}`);
const authUsers = (chunk) =>
  chunk.map((uid) => ({
    uid,
    emailVerified: uid !== 'user-3',
    disabled: uid === 'user-4',
  }));

describe('notification audience Auth boundary', () => {
  it('rejects a middle chunk without returning partial recipients or raw errors', async () => {
    const calls = [];
    const secret = 'private Auth SDK detail';

    await assert.rejects(
      verifiedEnabledAuthIds(ids, async (chunk) => {
        calls.push(chunk);
        if (calls.length === 2) throw new Error(secret);
        return authUsers(chunk);
      }),
      (error) => {
        assert.equal(error.message, 'notification-audience-auth-unavailable');
        assert.equal(error.message.includes(secret), false);
        return true;
      },
    );

    assert.deepEqual(calls.map((chunk) => chunk.length), [100, 100]);
  });

  it('a later invocation recovers the full deduplicated eligible audience', async () => {
    const calls = [];
    const audience = await verifiedEnabledAuthIds(
      [...ids, 'user-0', 'user-1', '', 'x'.repeat(129)],
      async (chunk) => {
        calls.push(chunk);
        return authUsers(chunk);
      },
    );

    assert.deepEqual(calls.map((chunk) => chunk.length), [100, 100, 5]);
    assert.equal(audience.size, 203);
    assert.equal(audience.has('user-0'), true);
    assert.equal(audience.has('user-3'), false);
    assert.equal(audience.has('user-4'), false);
    assert.equal(audience.has('user-204'), true);
  });
});

describe('notification retry configuration', () => {
  it('retries only notification Firestore triggers', () => {
    const functions = require('../lib/index');
    const retrying = Object.entries(functions)
      .filter(([, value]) => value?.__endpoint?.eventTrigger?.retry === true)
      .map(([name]) => name)
      .sort();

    assert.deepEqual(retrying, [
      'onAppointmentCreated',
      'onJoinRequested',
      'onJoinRequestedAtRegistration',
      'onSurveyCreated',
      'onTimeSlotConfirmed',
    ]);
  });

  it('gives reminders one retry without changing the purge schedule', () => {
    const { remindExpiring, purgeScheduledCompanies } = require('../lib/index');

    assert.equal(
      remindExpiring.__endpoint.scheduleTrigger.retryConfig.retryCount,
      1,
    );
    assert.equal(
      purgeScheduledCompanies.__endpoint.scheduleTrigger.retryConfig.retryCount,
      undefined,
    );
  });
});
