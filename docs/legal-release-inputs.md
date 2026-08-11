# Privacy, deletion, and store release inputs

This is an internal owner/legal input template and release gate. It is not a
privacy policy, legal advice, a store declaration, or evidence that any public
page has been deployed.

The repository now contains Firebase-independent static entry pages at
`/privacy-policy/` and `/account-deletion/`, with matching public Flutter routes
at `/privacy-policy` and `/account-deletion`. No production origin is asserted
here. The privacy page deliberately identifies itself as unapproved until the
inputs below are supplied and reviewed.

## Owner and legal approval record

Every field in this section requires an accountable owner or legal reviewer.
Do not copy the bracketed prompts into a public policy as if they were facts.

| Required input | Approved value or evidence |
| --- | --- |
| Controller/operator legal identity | `[OWNER INPUT REQUIRED]` |
| Controller/operator address, if applicable | `[OWNER/LEGAL INPUT REQUIRED]` |
| Approved privacy/support contact | `[OWNER INPUT REQUIRED]` |
| Policy effective date and version | `[OWNER/LEGAL INPUT REQUIRED]` |
| Approved production origin | `[OWNER INPUT REQUIRED AFTER DEPLOYMENT]` |
| Public privacy-policy URL | approved origin plus `/privacy-policy/` |
| Public account-deletion URL | approved origin plus `/account-deletion/` |
| Data-use purpose for each category | `[OWNER/LEGAL INPUT REQUIRED]` |
| Legal basis for each purpose | `[LEGAL INPUT REQUIRED]` |
| Retention period or deletion trigger for each category | `[OWNER/LEGAL INPUT REQUIRED]` |
| Backup retention and deletion behavior | `[OWNER/LEGAL INPUT REQUIRED]` |
| Legal or operational deletion exceptions | `[OWNER/LEGAL INPUT REQUIRED]` |
| Verified processors/subprocessors and transfer disclosures | `[OWNER/LEGAL INPUT REQUIRED AFTER PRODUCTION REVIEW]` |
| User rights, request handling, and complaint route | `[LEGAL/OWNER INPUT REQUIRED]` |
| Age, children, and target-audience position | `[OWNER/LEGAL INPUT REQUIRED]` |
| Signed-out help path for a person who cannot recover access | `[OWNER INPUT REQUIRED]` |
| Google Play Data Safety answers | `[OWNER INPUT REQUIRED AFTER BUILD/CONSOLE REVIEW]` |
| Store app-access instructions and reviewer account | `[OWNER INPUT REQUIRED]` |

## Source-level data inventory for review

The current source handles authentication email, full name, birth date, company
membership and role, an optional profile image, push device tokens and locale,
private notes, survey/test responses and scores, appointment votes, and company
administration and ban records.

Source dependencies include Firebase Authentication, Cloud Firestore, Cloud
Storage, Cloud Functions, App Check, and Firebase Cloud Messaging. That list is
not a processor/subprocessor declaration. A release owner must compare the
release build, Firebase/Google Cloud console configuration, contracts, enabled
services, regions, logs, and any services outside this repository before making
public claims.

The signed-in app sends an account-deletion request through a trusted function.
The source intends to remove the Auth sign-in only after application cleanup
reports success, and shared company content can retain an anonymous author
marker. This is implementation evidence, not proof of complete deletion,
retention, backup handling, or legal exceptions. The F-06/F-11 lifecycle gates
must pass before public copy can make stronger completion claims.

No safe signed-out deletion-request backend, approved support address, or other
support destination is present in this checkout. The public deletion page
therefore collects no email or account identifier, performs no account lookup,
and gives the same in-app sign-in and password-reset instructions to everyone.
Do not add a request form until its destination, authentication/abuse controls,
privacy handling, ownership, and non-enumerating response have been approved.

## Publication and store release gates

- Replace the privacy page's `owner-input-required` status only with
  owner/legal-approved copy mapped to the verified production behavior.
- Review translations of the approved policy; the current English, German, and
  Albanian pages only localize the technical release status and source facts.
- Deploy through the approved release process, then record the exact origin and
  verify both public pages from a signed-out browser, including direct refresh.
- Verify the in-app privacy and deletion links in every supported locale.
- Prove the deletion lifecycle independently; do not infer completion from a
  missing parent record or from the information page.
- Approve an operational procedure for people who cannot sign in or recover
  access. Any response must avoid revealing whether an account exists.
- Reconcile the release build and console configuration with Google Play Data
  Safety, app-access, permissions, ads, target-audience, and other declarations.
- Archive the approved policy version, legal/owner approval, deployment
  evidence, public reachability checks, and store submission evidence.

Until those gates pass, the technically complete status is:

**DONE LOCALLY — PRODUCTION ROLLOUT PENDING**
