# Verified onboarding

New registrations deliberately create no company, company-name lock, company
directory entry, member directory entry, or profile image before Firebase Auth
confirms the email address.

## Flow

1. The client creates the Auth account and sends Firebase's verification mail.
2. It writes one owner-only `users/{uid}` document with `companyId: ""`, the
   base profile, and exactly one private intent:
   - `createCompany` plus `pendingCompanyName`, or
   - `joinCompany` plus `pendingCompanyId`.
3. The client signs out so the next login obtains a fresh ID token containing
   the verified-email claim.
4. Every protected entry route passes through `DeferredOnboardingGate`. If an
   intent remains after a browser refresh, app restart, or ambiguous network
   response, the gate calls `completeOnboarding` again.
5. The callable requires Auth, App Check, the verified token claim, and a fresh
   Admin Auth lookup. Its transaction either creates every required tenant and
   member document together or creates none of them.

Company-name conflicts and unavailable/closing/banned join targets leave the
private intent intact. The gate lets the user choose a new name or public
company and safely retries the same transaction.

## Release order

This repository does not deploy or enable production enforcement.

Before releasing, register the App Check providers/tokens described in
`docs/app-check.md`. Deploy the callable and updated client together, then
publish these Firestore rules in the same controlled release window. Old
clients use the retired direct-registration batch and will be denied after the
new rules are active.

The rules/function change prevents new unverified reservations. It intentionally
does not delete historic companies or name locks. Before declaring a production
tenant clean, use an authorized Admin SDK audit to compare each company owner
with Firebase Auth `emailVerified`; review any historic unverified owner rather
than deleting it automatically.
