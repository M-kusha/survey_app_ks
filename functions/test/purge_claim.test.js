const assert = require('node:assert/strict');
const test = require('node:test');
const { Timestamp } = require('firebase-admin/firestore');

const { claimCompanyPurge } = require('../lib/purge');

const companyId = 'company-1';
const nowMillis = 1_700_000_000_000;

class MemoryPurgeDb {
  constructor(data) {
    this.data = data;
    this.updates = 0;
  }

  collection(name) {
    assert.equal(name, 'companies');
    return { doc: (id) => ({ id }) };
  }

  async runTransaction(operation) {
    const writes = [];
    const result = await operation({
      get: async (reference) => ({
        exists: reference.id === companyId && this.data != null,
        data: () => this.data,
      }),
      update: (_reference, fields) => writes.push(fields),
    });
    for (const fields of writes) {
      this.data = {
        ...this.data,
        ...fields,
        purgeStartedAt: Timestamp.fromMillis(nowMillis),
      };
      this.updates += 1;
    }
    return result;
  }
}

test('claims only a due company and resumes the same immutable claim', async () => {
  const future = new MemoryPurgeDb({
    deletionScheduledFor: Timestamp.fromMillis(nowMillis + 1),
  });
  assert.equal(await claimCompanyPurge(future, companyId, nowMillis), false);
  assert.equal(future.updates, 0);

  const due = new MemoryPurgeDb({
    deletionScheduledFor: Timestamp.fromMillis(nowMillis),
  });
  assert.equal(await claimCompanyPurge(due, companyId, nowMillis), true);
  assert.equal(due.updates, 1);
  assert.equal(due.data.purgeStartedAt instanceof Timestamp, true);

  assert.equal(await claimCompanyPurge(due, companyId, nowMillis + 1), true);
  assert.equal(due.updates, 1);
});

test('missing, malformed and no-longer-scheduled companies fail closed', async () => {
  const missing = new MemoryPurgeDb(null);
  assert.equal(await claimCompanyPurge(missing, companyId, nowMillis), false);

  const unscheduled = new MemoryPurgeDb({ name: 'Company' });
  assert.equal(
    await claimCompanyPurge(unscheduled, companyId, nowMillis),
    false,
  );

  const malformed = new MemoryPurgeDb({
    deletionScheduledFor: Timestamp.fromMillis(nowMillis),
    purgeStartedAt: 'forged',
  });
  await assert.rejects(
    claimCompanyPurge(malformed, companyId, nowMillis),
    /purge marker is malformed/,
  );
  assert.equal(malformed.updates, 0);
});
