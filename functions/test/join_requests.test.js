const assert = require('node:assert/strict');
const { describe, it } = require('node:test');

const { joinRequestCompanyId } = require('../lib/join_requests');

describe('join request notification gate', () => {
  it('notifies for a real pending join', () => {
    assert.equal(
      joinRequestCompanyId(
        { companyId: 'company-acme', membership: 'pending' },
        false,
      ),
      'company-acme',
    );
  });

  it('suppresses active-to-pending membership mirroring caused by a ban', () => {
    assert.equal(
      joinRequestCompanyId(
        { companyId: 'company-acme', membership: 'pending' },
        true,
      ),
      null,
    );
  });

  it('suppresses non-pending and companyless profiles', () => {
    assert.equal(
      joinRequestCompanyId(
        { companyId: 'company-acme', membership: 'active' },
        false,
      ),
      null,
    );
    assert.equal(
      joinRequestCompanyId({ companyId: '', membership: 'pending' }, false),
      null,
    );
  });
});
