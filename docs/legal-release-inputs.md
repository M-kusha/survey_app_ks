# Legal and store-listing release inputs

The repository provides the product behavior and a public account-deletion
route, but it cannot invent the operator's legal identity, contact details,
retention commitments, or store declarations. A release owner must approve and
publish those facts before a store submission.

## Required external inputs

- Public privacy-policy URL, controller/operator identity, and support contact.
- Any terms-of-service URL required by the chosen distribution or jurisdiction.
- Apple App Privacy and Google Play Data Safety answers reviewed against the
  exact production configuration.
- A documented retention/backup policy and support procedure for people who
  cannot recover access to their account.
- Confirmation that the public deletion page is deployed and reachable at
  `https://echomeet-app.web.app/#/account-deletion` (or the final custom-domain
  equivalent).

## Source-level data inventory

The current client and backend handle authentication email, full name,
birthdate, company membership and role, an optional profile image, push device
tokens and locale, private notes, survey/test responses and scores, appointment
votes, and company administration/ban records. Account deletion removes or
anonymizes these at a trusted server boundary; an owner is warned that deleting
their account also destroys owned company content.

No analytics, advertising, or crash-reporting SDK is currently declared. This
inventory must be rechecked from the release build and Firebase Console because
console-enabled services and future dependencies are not proven by source alone.

This document is a release gate and engineering inventory, not a privacy policy
or legal advice.
