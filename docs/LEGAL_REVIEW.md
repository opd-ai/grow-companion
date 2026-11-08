# Legal and privacy review — current branch

> **Gate status.** The product owner has confirmed that the legal review gate is
> cleared for the file-based, recipient-scoped share feature described in
> `docs/E2EE_DESIGN.md`. The findings below remain the engineering record, and the
> items in section 4 that concern App Store submission (privacy labels, published
> policy and terms) still need their own sign-off; they are not resolved by that
> confirmation.

This is an engineering and product compliance review of the app's user-facing
claims, consent copy and data-handling surfaces. **It is not legal advice, it
was not written by a licensed attorney, and it does not create a
solicitor-client relationship.** Items that need a qualified lawyer are listed
separately in section 4 and remain open.

## 1. Scope and method

Reviewed: onboarding and age attestation, rule and compliance copy, the sharing
and sync surfaces, permission strings in `Info.plist`, the delete/export/backup
copy, notification wording, and the roadmap's claimed capabilities. Every
finding was checked against the code path that produces the claim, not only
against documentation.

Governing principle applied throughout: the app must not claim a capability it
does not have, must not present a computed estimate as legal advice, must not
imply a guarantee of lawfulness, and must not collect personal data for a
feature that does not exist.

## 2. Findings and dispositions

| ID | Finding | Severity | Action taken |
|---|---|---|---|
| L-01 | The sharing screen created "shares", implied a recipient was authorised, and supported a recipient revocation flow, with no transport, recipient identity, authentication or encryption. | High | Sharing screen is now a "not available" page: no create flow, no capability claims, and existing local records are labelled as local notes that grant nothing, with a delete action. Schema unchanged. |
| L-02 | The encrypted-sync screen showed an "encryption on/off" state, implied a provider and account identifiers, and claimed record contents were unreadable to a provider. No sync engine exists. | High | Screen rewritten as "This device only", stating there is no account, server or sync. Fake status keys removed. Settings row relabelled. |
| L-03 | The rule pack's dates were presented as "verified", which reads as a legal verification the app cannot attest. | Medium | UI now says "rules last updated", and the verification-duty copy states the totals are an estimate from the bundled pack. |
| L-04 | No explicit statement that the app is not legal advice. | High | Added to `LegalCopy.verificationDuty` and surfaced on every compliance and rules surface that already shows the verification duty. |
| L-05 | The location permission string and onboarding copy claimed coordinates are never sent anywhere, while the reverse-geocoding lookup uses Apple's service. | Medium | Permission string, onboarding copy and code comment now describe the Apple lookup accurately and state only that the app keeps the resolved state or locality name. |
| L-06 | The onboarding headline called the grow "legal", which implies a guarantee. | Medium | Headline now reads "A home grow, kept in order." |
| L-07 | "Critical" notification priority claimed it "breaks through quiet hours", while the implementation only bypasses the app's own quiet-hour adjustment and uses a time-sensitive interruption level. | Low | Subtitle now matches the implementation. |
| L-08 | An unused API-key helper performed an encrypted-file import at launch and derived its key from the bundle identifier, i.e. obfuscation rather than protection, with no feature using it. | Medium | File deleted. No references remained. |
| L-09 | Age attestation copy did not say explicitly that it is self-attestation rather than verification. | Medium | Copy now states it is a self-attestation, never an identity check. |
| L-10 | Export, backup and delete copy implied or left ambiguous what the app can delete. | Medium | Copy states that Files exports, device backups and iCloud backups are outside the app and are not removed. |

## 3. Product constraints this review sets

- No sale, gifting, transfer, transport, distribution or diversion pathway may be
  added. Harvest dispositions stay limited to consumed at home, destroyed and
  retained.
- No health, diagnosis or treatment claims; education content stays framed as
  general guidance.
- No analytics, advertising, third-party SDK or background upload.
- Any future sharing, community, sync, sensor or photo-analysis feature requires
  a privacy review, a legal review, and a threat model before it is described in
  the app as available.

## 4. Requires qualified counsel

These cannot be resolved in code and remain open. They are recorded so they are
not silently assumed to be settled:

1. Whether cultivation, jurisdiction, harvest, treatment and compliance data are
   consumer health data under Washington's My Health My Data Act, CCPA/CPRA or
   comparable state regimes, and what notices and rights are required.
2. Age assurance obligations: whether self-attestation is sufficient, and
   whether any age signal may be retained.
3. Biometric-privacy notices (for example BIPA) for the Face ID lock, including
   the statement that biometric templates never enter the app.
4. App Store privacy-label accuracy for local storage, photos, location,
   diagnostics and exports, and whether the app's declarations match the binary.
5. Whether the in-app deletion flow can be described as deleting "everything"
   when Apple backups and Files exports remain outside app control.
6. Review of the bundled rule text, citations, effective dates and every
   computation per jurisdiction, and sign-off on any future rule-pack change.
7. Terms of use and a privacy policy suitable for distribution. The app carries
   in-app notices but no separate published policy; a policy URL is required for
   App Store submission.
8. Any future sharing, community, sync, sensor integration, photo analysis or
   laboratory interpretation.

Until those are answered, the product posture is: local-only, account-free,
sharing and sync unavailable, rule content labelled as an estimate with a
verification duty, and no claim of legal compliance. The protected-envelope code
described in `docs/E2EE_DESIGN.md` is foundation only: it is not used to send
anything, and it must not be presented as end-to-end encryption of a shipped
feature.
