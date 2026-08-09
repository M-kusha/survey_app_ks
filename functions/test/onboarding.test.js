const assert = require('node:assert/strict');
const test = require('node:test');

const { companyNameSlug } = require('../lib/onboarding');

test('company name locks use one canonical server-owned spelling', () => {
  assert.equal(companyNameSlug('  Café & Co.  '), 'caf-co');
  assert.equal(companyNameSlug('ACME---North'), 'acme-north');
  assert.match(companyNameSlug('公司'), /^unicode-[a-f0-9]{64}$/);
  assert.equal(companyNameSlug('***'), '');
});
