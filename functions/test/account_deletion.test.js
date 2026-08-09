const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const { hasRecentAuthentication } = require('../lib/account_deletion');

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
});
