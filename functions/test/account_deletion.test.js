const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const {
  CompanyOwnerDeletionError,
  establishAccountDeletionWriteBarrier,
  hasRecentAuthentication,
} = require('../lib/account_deletion');

function barrierStore(companyIds = []) {
  const events = [];
  const writes = [];
  const reference = (path) => ({ path });
  const ownedCompanyQuery = { path: 'companies?createdBy=user-1' };
  const docs = companyIds.map((id) => ({
    id,
    ref: reference(`companies/${id}`),
  }));
  return {
    db: {
      collection: (name) => ({
        doc: (id) => reference(`${name}/${id}`),
        where: (field, operator, value) => {
          assert.deepEqual([name, field, operator, value], [
            'companies', 'createdBy', '==', 'user-1',
          ]);
          return ownedCompanyQuery;
        },
      }),
      runTransaction: async (operation) =>
        operation({
          get: async (query) => {
            assert.equal(query, ownedCompanyQuery);
            events.push(['get', query.path]);
            return { docs, empty: docs.length === 0, size: docs.length };
          },
          set: (ref, data) => {
            events.push(['set', ref.path]);
            writes.push(['set', ref.path, data]);
          },
          update: (ref, data) => {
            events.push(['update', ref.path]);
            writes.push(['update', ref.path, data]);
          },
        }),
    },
    events,
    writes,
  };
}

describe('trusted account-deletion authorization', () => {
  const now = 2_000_000_000;

  it('accepts a recent reauthentication', () => {
    assert.equal(hasRecentAuthentication(now - 120, now), true);
  });

  it('rejects a stale authentication', () => {
    assert.equal(hasRecentAuthentication(now - 301, now), false);
  });

  it('rejects missing or malformed auth_time claims', () => {
    assert.equal(hasRecentAuthentication(undefined, now), false);
    assert.equal(hasRecentAuthentication('recent', now), false);
  });

  it('allows small clock skew but rejects implausible future claims', () => {
    assert.equal(hasRecentAuthentication(now + 30, now), true);
    assert.equal(hasRecentAuthentication(now + 61, now), false);
  });

  it('discovers ownership inside the transaction before writing barriers', async () => {
    const open = barrierStore(['company-1']);
    const owned = await establishAccountDeletionWriteBarrier(
      open.db,
      'user-1',
      true,
      1_000,
    );
    assert.deepEqual(owned.map(({ id, ref }) => [id, ref.path]), [
      ['company-1', 'companies/company-1'],
    ]);
    assert.deepEqual(open.events, [
      ['get', 'companies?createdBy=user-1'],
      ['set', 'accountDeletionLocks/user-1'],
      ['update', 'companies/company-1'],
    ]);
    assert.equal(open.writes[0][2].expiresAt.toMillis(), 7_201_000);
    assert.equal(open.writes[1][2].deletionScheduledFor.toMillis(), 1_000);
    assert.equal(open.writes[1][2].deletionRequestedBy, 'user-1');
  });

  it('refuses an owned-company deletion before writing either barrier', async () => {
    const blocked = barrierStore(['company-created-during-race']);
    await assert.rejects(
      establishAccountDeletionWriteBarrier(blocked.db, 'user-1', false, 1_000),
      CompanyOwnerDeletionError,
    );
    assert.deepEqual(blocked.events, [
      ['get', 'companies?createdBy=user-1'],
    ]);
    assert.deepEqual(blocked.writes, []);
  });

  it('locks a personal account that owns no company', async () => {
    const personal = barrierStore();
    const owned = await establishAccountDeletionWriteBarrier(
      personal.db,
      'user-1',
      false,
      1_000,
    );
    assert.deepEqual(owned, []);
    assert.deepEqual(personal.events, [
      ['get', 'companies?createdBy=user-1'],
      ['set', 'accountDeletionLocks/user-1'],
    ]);
  });
});
