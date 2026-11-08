# Grow Companion — Safe Release Feature Plan

> **Implementation status on this branch:** SAFE-01 is implemented and documented
> in `docs/DATA_SAFETY.md`. COMP-01 is implemented and documented in
> `docs/COMPLIANCE_HISTORY.md`: an explicit V1/V2 schema with one lightweight
> additive migration, append-only `ComplianceSnapshot` records, append-only
> `RuleEvaluationEvent` reviews, a rule-update banner on Home and Rules, a
> history list and detail, and full export/backup/restore/delete coverage with
> tests. The release gates in both specs — legal review of changed rule content,
> staged rollout, privacy sign-off, real migration fixtures and the iOS 18
> decision — remain open. Nothing here enables sync, sharing, community, the
> personal effect journal, Watch/Siri or any transaction pathway.

## 1. Summary

Recommend a deliberately small, local-first release that closes the known data-access and data-control gaps before adding cloud, sharing, or community capability. The first release hardens lock behavior, startup recovery, backup/restore, export and delete-all without changing the cultivation-store schema; a following release adds immutable compliance history and visible rule-pack change events behind a tested migration. The largest risk is existing-user data loss or misleading compliance history: the repository has no explicit SwiftData migration plan, compliance snapshots are not persisted, and the privacy review identifies a fail-open app-lock path and incomplete export/delete coverage. Neither release enables sync, third-party sharing, personal effect journaling, or any sale, distribution, transport, or diversion capability.

**Planning context confirmed from the repository**

- **Released version/build history:** The Xcode project currently carries placeholder `MARKETING_VERSION = 1.0` and `CURRENT_PROJECT_VERSION = 1`. The TestFlight workflow overrides those with a tag/manual version and GitHub Actions run number. No App Store Connect/TestFlight release history is present in the repository, so the actual released version, build history, and whether 1.0/1 was ever distributed are unknown.
- **Installed base/active rate:** Unknown. The repository contains no analytics or crash-reporting implementation, and no metrics were supplied. Assume no permitted user-level telemetry for this plan.
- **Rule jurisdictions:** The bundled `RulePack` is version `2025.05.1`, marked verified 2025-05-15 in source. `JurisdictionData` contains 50 state entries plus DC. The code marks these entries cultivable: AK, AZ, CA, CO, CT, DE, DC, HI, IL, ME, MD, MA, MI, MN, MO, MT, NV, NM, NY, OH, OR, RI, VT, VA; remaining entries are marked non-cultivable in that bundled dataset. This is a description of repository data, not a conclusion about current law. No county/city rule engine is evidenced.
- **Schema versions:** The cultivation store is SwiftData configured as `GrowCompanion`, but the code declares no `VersionedSchema`, schema version, or `SchemaMigrationPlan`; its formal version is unknown. A separate personal effect journal store/schema does not exist in the source. The current `JournalEntry` is cultivation journal data and is linked to plants/rooms; it is not a personal effect journal.
- **Sync/E2EE:** No CloudKit, app-owned network sync, or E2EE implementation is present. `SyncPrivacyView` is a status/explanation surface backed by local `@AppStorage` values, not a sync engine. Legal copy says there is no cloud sync. There is therefore no real sync state or sync conflict policy today.
- **Shipped capabilities (as documented in `docs/ROADMAP.md`):** onboarding/age attestation and jurisdiction selection; local rules and stale badges; compliance ring and breakdown; rooms/plants; light schedules; environment/feed/calibration logging; reminders and local notifications; cultivation journal/photos; harvest/drying/curing; strains; training; treatments; equipment/service history; scouting; weekly recap, room comparison and cycle archive; password-protected local backup/restore; app lock/privacy cover; export/delete controls. The roadmap labels several items partial, and source implementation should be checked against each acceptance criterion before calling them complete.
- **In flight/partial:** There is no authoritative in-flight tracker. The roadmap calls plant-count pre-save preview and rule-change notices partial; Watch/Siri watering is blocked on platform work; sustained environment alerts are roadmap-planned but model/service/editor code already exists; sharing screens and local `ShareGrant` models exist but do not constitute remote sharing; sync screen state is not a sync implementation. Treat each as unshipped until a release artifact proves otherwise.
- **Known defects/review findings:** `docs/PRIVACY_REVIEW.md` (dated 2025-06-14; its currentness needs confirmation) identifies a fail-open app lock when device-owner authentication cannot be evaluated; export/delete omissions for newer models including treatments and equipment; incomplete deletion boundaries for external backups/exports; incomplete verification of store-file protection; export password derivation using HKDF directly from password bytes; and lack of migration, corruption, and recovery tests. It also states sync, signed remote rules, personal effect journal, and audit snapshots are not implemented. The test target is currently a placeholder. Crash rates and open support-ticket counts are unknown.
- **Outstanding review findings:** The privacy review lists legal questions about consumer-health-data laws, age attestation, biometrics, App Store privacy disclosures, deletion boundaries, rule/content exposure, and future sharing/community/sensor/analytics. No resolution evidence is in the repository.
- **Platform mismatch to resolve:** The prompt requires iOS 18+, while the project currently sets `IPHONEOS_DEPLOYMENT_TARGET = 26.0`. Confirm whether this is only a development placeholder. The release plan assumes iOS 18+ is a real requirement and makes an iOS 18 compatibility build/test a pre-release gate.

## 2. Release scope

| ID | Feature | Tier/origin | Priority | Target | Blocking dependencies |
|---|---|---|---|---|---|
| SAFE-01 | Local data safety and recovery closure | Enabling work; privacy-review findings F-03/F-04/F-05/F-06/F-08 | P0 | Next candidate release; version unset | Fail-closed lock; complete model inventory; versioned backup format; recovery tests; privacy review; iOS 18 target confirmation |
| COMP-01 | Immutable compliance history and rule-change review | Roadmap story 2 (partial) plus compliance audit gap O-06 | P1 | Following release, only after SAFE-01 | Verified backup/restore from SAFE-01; migration fixtures; rule-content/legal review for every changed jurisdiction rule; no sync dependency |

**Explicitly excluded from these releases:** remote rule downloads, E2EE sync, consultant/peer sharing, community, personal effect journal, Watch/Siri, photo analysis, lab interpretation, health recommendations, and any transaction/status implying transfer. Sharing and community remain blocked pending attorney review. Existing records and dispositions are not repurposed: harvest disposition remains limited to `consumed at home`, `destroyed`, and `retained`; no sale, gifting, transfer, transport, or distribution state is introduced.

## 3. Feature specifications

### SAFE-01 — Local data safety and recovery closure

**1. Problem statement and user segment**

Adults with existing grow records, cultivation-journal photos, harvest/cure history, treatment history, equipment/service records, or app lock enabled are exposed to misleading success if the store fails, a lock cannot authenticate, or a newer record is omitted from export/delete. The privacy review reports the concrete export/delete gap and fail-open lock path; no support counts or usage rates are available, so prioritize by severity rather than invented frequency. This is a trust and data-safety release, not a feature-growth release.

**2. User stories and testable acceptance criteria**

- As a grower with app lock enabled, I want the app to remain covered unless authentication succeeds. **Given** device-owner authentication is unavailable, restricted, cancelled, or returns an error, **when** the app requests unlock, **then** protected content remains covered and no code path sets the lock state to unlocked. **Given** authentication succeeds, **then** the protected root becomes available.
- As a grower, I want a failed store open to be distinguishable from an empty grow. **Given** SwiftData cannot open the persistent store, **when** the app starts, **then** it shows a recovery state, does not silently substitute an in-memory store, does not present an empty grow as saved data, and disables create/edit/delete actions until recovery or an explicit new-grow action is chosen.
- As a grower, I want an export/backup to include the records I chose. **Given** one instance of every model registered in the app's `Schema`, **when** I export, **then** the archive manifest reports counts by model and every in-scope record is represented in JSON; documented CSVs are generated for supported tabular categories; photo inclusion follows the user's explicit setting; no location metadata is included.
- As a grower, I want to restore an older backup without losing data silently. **Given** a valid v1 backup, **when** the current app restores it, **then** the importer reads it and presents a pre-restore backup/replacement summary before any replacement. **Given** an unknown or corrupt format, **then** import is rejected without modifying the current store.
- As a grower, I want delete-all to be complete and honestly scoped. **Given** every current model, photo, cache entry, notification and app preference exists, **when** the user completes the typed confirmation, **then** all in-scope local app records/files are deleted and the completion screen verifies zero remaining model counts; copies in Files, user exports and OS/device backups are explicitly identified as outside the app's deletion control.
- As a grower, I want a failed write not to appear successful. **Given** a data-control operation fails due to storage, permissions, or serialization, **then** the UI shows an actionable error, preserves the source records, and does not claim completion.

**3. UX flow and screen changes**

- **iPhone:** Settings → Privacy and data. Add a clear backup/export content manifest and last-operation result; keep the existing explicit journal/photo choice for the *cultivation* journal. Add Recovery state at launch with options `Try again`, `Restore a verified backup`, and `Start a new grow` (the last requires separate typed confirmation and never overwrites the unreadable store). App-lock unavailable/error state explains that a device passcode/authentication policy is required and offers no fail-open route. Delete completion lists local data removed and external copies not controlled.
- **iPad:** Same controls and copy in the existing adaptive Settings navigation; use a two-column detail only when it preserves the complete count manifest and confirmation in one reading order. Restore confirmation stays modal and blocks background editing.
- **Companion surfaces:** No widget, Watch, Siri, share extension, community, or cloud surface is added. Files export is the only external surface and must use a neutral, non-identifying filename. Offline and online UI are identical because this feature performs no network operations.
- **Empty/error states:** Empty data produces a successful zero-count manifest; missing/corrupt store produces Recovery, never a blank Home screen. Invalid password, unsupported backup version, disk-full, interrupted export, interrupted restore, and delete failure each display a specific non-destructive error and preserve the source.

**4. Data model changes**

- **Cultivation store:** No SwiftData model/entity/relationship change and no cultivation schema bump in SAFE-01. Freeze and test the existing model registry as an explicit coverage manifest.
- **Export/backup format:** Bump the JSON export `formatVersion` and backup envelope `backupVersion` from 1 to 2. V2 adds a model-count manifest, model completeness, an explicit schema/producer version, encryption envelope version/KDF parameters, and a clear declaration of optional photos/cultivation-journal inclusion. Keep a v1 decoder. Unknown newer versions fail closed.
- **Personal effect journal:** No separate store exists. Do not create one here, infer it from `JournalEntry`, or link it to any grow record. Current cultivation journal inclusion stays opt-in as it is today.
- **Compliance snapshots/reference/sharing metadata:** No changes; no compliance snapshot model currently exists. Any existing local `ShareGrant` records are included in data controls only if current user-facing feature semantics say they are user data; they are not interpreted as network shares.

**5. Migration and backward compatibility**

- No cultivation-store schema migration is performed in SAFE-01. Existing SwiftData model names, IDs, relationships, plant history, and compliance-relevant values are read-only inputs to export/backup; no normalization or bulk rewrite is permitted.
- Current app reads v1 backups and writes v2. V1 backups remain unchanged and recoverable. Older app versions may not understand v2; the app must label v2 as a newer format when encountered by old software rather than attempting a partial import. Never rewrite v1 archives in place.
- Before any later schema migration, SAFE-01 must provide an encrypted, file-protected backup, verify archive authentication and model counts, and preserve the original store until the migrated copy passes validation. Restore is staged to a temporary store and only swapped after verification.
- Delete-all reports local app-controlled copies only. It does not claim removal from iCloud/device backups, Files, screenshots, or user-created exports. No migration or deletion is automatic or irreversible without the explicit confirmation path.

**6. Offline behavior and sync conflict handling**

- Export, backup, restore, lock, recovery, and delete operate fully offline. No write is queued for a future server.
- Sync is not implemented, so no multi-device merge is claimed. Repeated local export uses a new archive and does not alter records. Restore into a non-empty store is a replacement flow only after a verified backup of the current store and explicit confirmation; the importer never merges by display name or silently picks a winner.
- For interrupted operations, use atomic staging and commit/rename only after full validation. If the platform cannot guarantee the atomic step, keep the original and surface recovery instructions.

**7. Privacy and security impact**

- No new user data collection, network endpoint, analytics, identity, or third-party SDK. Data stays on device except when the user explicitly exports through Files.
- Keep database and private files protected at rest; verify actual store, temporary staging, and photo files rather than relying only on the parent directory's protection attribute. Export warnings state that files moved to Files are outside app control.
- Replace direct-password HKDF derivation for *new* v2 exports with a password KDF designed for password guessing resistance (use an Apple-provided/system implementation available to the deployment target, with versioned parameters, random salt, authenticated encryption, and test vectors). Keep v1 decryption only for migration, and never re-encrypt a v1 archive without user action. Do not add a third-party package for this.
- App lock fails closed. While locked, no record names, rooms, measurements, products, or harvest details appear in recovery/deletion notifications or system previews. This is a privacy-review gate before release.
- Personal effect journaling remains absent and strictly out of scope; no shared IDs, timestamps, file paths, metadata, indexes, or analytics are introduced.

**8. Compliance impact**

- No rule pack, jurisdiction data, `ComplianceEngine`, plant-count, possession/canopy logic, alerts, or legal copy calculation changes. Existing harvest dispositions stay limited to consumed at home, destroyed, retained.
- The repository does not currently persist historical compliance snapshots. SAFE-01 must not fabricate them or imply that an export contains an audit history that was never recorded. Preserve all existing grow records and the exact current compliance result behavior.

**9. Accessibility requirements**

- VoiceOver labels identify the action and scope, e.g. `Export cultivation records`, `Include cultivation journal and photos`, `Restore backup version 1`, `Delete local records`. Reading order is heading → included/excluded categories and counts → action → consequence/warning → confirmation.
- At the largest Dynamic Type sizes, the manifest and confirmation use a vertically scrolling layout with wrapped labels; no count or warning is clipped, and destructive buttons remain distinct from cancel.
- Reduce Motion removes transition animation from recovery/success state changes; status is conveyed with text and symbol, not color alone.
- Localize all visible copy, number/date/weight units, password/KDF errors and pluralized model counts. Legal copy is not translated without qualified legal localization review.

**10. Telemetry**

- No remote telemetry. In local QA builds only, record aggregate operation outcome (success/failure category, format version, model count total) without grow identifiers, names, text, values, location, photos, or stable user/device IDs; do not upload it. Release builds rely on opt-in, user-initiated diagnostics with preview/redaction before sharing.
- Success is measured through TestFlight task completion and support-ticket classification, not instrumentation of grow records.

**11. Test plan**

- Unit: v1/v2 archive parser, KDF envelope version/parameters, tamper rejection, unsupported version rejection, manifest counts, status enum allowlist, EXIF stripping, and model registry coverage test comparing every registered `@Model` type against export/backup/delete coverage.
- Integration: seed every current model and photo; export with each journal/photo option; import v1 and v2; assert values, relationships and photo bytes; delete all and inspect SwiftData, files, caches, notifications and preferences. Compare pre/post counts and stable record fingerprints, excluding intentionally omitted preferences.
- Migration/recovery: no SwiftData migration in this feature; test fixtures from all available released backups. Inject invalid key, full disk, partial write, interrupted restore, inaccessible store, corrupted store, and restart; assert source store is unchanged and the UI never shows a false success or empty in-memory grow.
- Offline: airplane-mode export/restore/delete; assert no network activity and no queued operation.
- Accessibility: VoiceOver audit of every confirmation/error path, largest Dynamic Type snapshot/manual audit, Reduce Motion, contrast, switch control, and iPhone/iPad navigation.
- Security: LocalAuthentication unavailable/restricted/cancel/error/success; backgrounding during lock; inspect app switcher, lock-screen notifications, export filenames, files' protection attributes, and archive metadata.

**12. Rollout plan**

- Add a local, default-on-after-update safety patch with no remote flag dependency. Ship to internal TestFlight first, then a 5% App Store phased release, 25%, 50%, 100% with at least one support/diagnostic review between steps. If App Store phased release is unavailable, use the equivalent approved staged-release mechanism.
- No jurisdiction gating: this feature does not alter legal content or user eligibility.
- Kill/rollback: stop staged release for any record-count mismatch, restore failure, lock fail-open, data-loss report, or crash increase above the team's existing release threshold (threshold currently unknown; set before rollout). A future build can disable optional v2 export writing while retaining v1 read support; never remotely delete or disable access to user records. Store open failure always routes to recovery, not memory-only mode.
- Release gate: resolve the iOS 26.0 vs iOS 18+ deployment-target discrepancy and pass CI on minimum iOS 18 and current iOS, iPhone and iPad.

**13. Support and documentation**

- Update Data/Privacy help with backup content, v1/v2 compatibility, password recovery limitation, local deletion boundary, and what is outside app control (Files exports and OS/device backups). Add a restore troubleshooting decision tree.
- For data-loss reports: instruct support to stop writes, do not reinstall or run delete-all, keep device available, attempt a file-protected backup only if the store opens safely, record app/build/OS and error category, and obtain the user's explicit consent before receiving any diagnostic archive. Never ask for cultivation contents by default. Escalate suspected corruption to engineering with a redacted reproduction fixture.

### COMP-01 — Immutable compliance history and rule-change review

**Implementation status:** implemented on this branch. See
`docs/COMPLIANCE_HISTORY.md` for the shipped behaviour, schema, migration,
comparison rules, data-control coverage, tests and open release gates.
`complianceHistoryWriteEnabled` is not shipped as a user-facing switch: the
write path is on, because the history is the feature. A staged rollout still
controls exposure at the release level.

**1. Problem statement and user segment**

Growers who use the compliance ring need to understand which rule-pack version produced a status and whether a later reviewed pack changes that status. The privacy review says current status is derived from current records and no persisted snapshot/history exists, so old results cannot currently be reconstructed from app data. No user behavior or support volume is available; this feature is justified by the trust requirement, not an invented demand estimate. It does not provide legal advice or change a jurisdiction-specific rule without attorney-reviewed rule content.

**2. User stories and testable acceptance criteria**

- As a grower, I want an immutable point-in-time record of the app's displayed compliance calculation. **Given** a compliance-relevant change (plant count/stage/disposition, retained dry weight, occupied-room canopy, selected jurisdiction, or applied rule-pack version), **when** the current calculation is successfully saved, **then** an append-only snapshot records timestamp, jurisdiction code, pack version, counted-stage totals, retained-weight estimate, canopy total, warning threshold, and per-metric status. It contains no plant/room names or foreign IDs.
- As a grower, I want to know when an included rule pack changes. **Given** the app detects a different bundled pack version, **when** the Rules or Home compliance surface opens, **then** a persistent notice identifies old/new pack versions, verified dates, and only the changed rule fields with their citations; acknowledgment is recorded as a separate event.
- As a grower, I want old results preserved. **Given** a new pack would evaluate a stored historical snapshot differently, **when** re-evaluation is possible from the inputs stored in that snapshot, **then** the app appends a new `RuleEvaluationEvent` referencing the old snapshot and new pack version, displays the changed result as a new event, and leaves the original snapshot bytes/values unchanged. If necessary inputs are missing or semantics are not comparable, **then** it records `not comparable` and does not infer a result.
- As a grower upgrading from a version with no history, I want honest baseline labeling. **Given** the first launch after upgrade, **then** the app may create one `Baseline after update` snapshot of the current state, clearly dated; it does not claim to reconstruct pre-update history.
- As a grower offline, I want the last bundled rule version and local history to remain available. **Given** no network, **then** history opens and current calculations use only the bundled pack; no status is silently changed by a remote fetch.
- As a grower, I want control over these records. **When** I export or delete all, then compliance snapshots/events are included in the data inventory/export and deleted only as part of the explicit delete flow; no unrelated personal journal data is included.

**3. UX flow and screen changes**

- **iPhone:** Home compliance card links to `History`; Rules surface shows pack version/verified date and a `Review rule update` banner. History is a chronological list of snapshot time, jurisdiction code/name, pack version, and summary. A detail view shows the exact metrics/threshold used, source rule citation and status. Rule review shows side-by-side changed fields, effective/verified dates and an explicit `Acknowledge update` action; acknowledgment never means legal acceptance or changes old data.
- **iPad:** Use a split view: history list and selected snapshot/change detail. At compact widths, use the same push navigation as iPhone. No extra companion surface.
- **Empty state:** `Compliance history starts with this update`; explain that earlier app builds did not save snapshots. **No rule change:** show `You're viewing pack …` and no fake update banner. **Offline:** banner says which bundled pack is in use and its verification date. **Error:** a failed snapshot write keeps the last successfully saved history, reports `History could not be saved`, and does not claim a new audit event exists; current compliance surface clearly labels its calculation as not yet saved.
- A rule update is delivered only as part of a reviewed app release in this scope. Remote signed packs are excluded until their separate integrity/security design is approved.

**4. Data model changes**

- **Cultivation store:** Add `ComplianceSnapshot` and `RuleEvaluationEvent` SwiftData models with stable UUIDs, immutable payload fields, and creation timestamps. Define an explicit versioned schema in the release. Planning baseline is legacy implicit schema → Cultivation schema v1 (same deployed model set, frozen exactly) → Cultivation schema v2 (adds these models); this names the migration path but does not assert a current numeric version. No destructive transform, no new plant/room relationships, no journal fields.
- Snapshot fields: `id`, `capturedAt`, `jurisdictionCode`, `rulePackVersion`, stage-count buckets required by the evaluator, stored-retained-amount estimate and unit, canopy total and unit, warning threshold, per-metric result enum, snapshot schema version, and `isUpgradeBaseline`. The model stores only inputs that the current evaluator actually uses. Do not add uncollected household-member counts, precise location, plant names, or assumptions.
- `RuleEvaluationEvent` fields: own UUID, prior snapshot UUID, prior/new pack version, evaluation timestamp, comparable/not-comparable outcome per metric, changed summary, and acknowledgment timestamp. It may reference a compliance snapshot only; never a personal effect journal record.
- **Personal effect journal:** Still absent. If introduced later, it must use a separately encrypted store/key and zero foreign keys/shared IDs/timestamps/photo metadata/search indexes/analytics as required; this feature creates none.
- **Export/backup:** Requires SAFE-01 v2 archive support before schema migration; include these new compliance records and schema version. **Delete:** include both new model types. **Sync:** none.

**5. Migration and backward compatibility**

- Before migration, create and verify the SAFE-01 v2 protected backup, including model counts and authentication tag. Capture fixtures from every released schema/build that can be obtained; no migration starts if backup verification fails or there is insufficient staging space.
- Define the exact deployed implicit model set as the source schema and test a single additive migration to v2. Preserve every preexisting model, relationship, photo file and identifier. Do not backfill historical snapshots from present-day records. At most, create one post-upgrade baseline event with an explicit `isUpgradeBaseline` label.
- Migrate a staged copy, validate all previous record counts/relationships plus expected new entities, then switch stores. Keep the untouched source/verified rollback backup until the user has reviewed the successful migration. Any failure leaves source bytes intact and enters recovery; no automatic reset or empty in-memory fallback.
- New app reads legacy backup v1 and writes v2. Older app versions are not allowed to open a partially migrated copy. If a downgrade build cannot read v2, it must show a recoverable unsupported-store state and direct the user to the verified backup/current compatible build; never overwrite the v2 store. Test the oldest supported app version on an isolated copy before release and document downgrade limits.
- Existing compliance results were not stored before this feature. Preserve all grow records and do not manufacture past snapshot history. Historical snapshots recorded after this update are never rewritten; a later rule comparison is a new event.

**6. Offline behavior and sync conflict handling**

- Snapshot creation and history display are on-device and offline. Use the bundled rules only. If persistence fails, keep grow-record writes independent where possible, clearly mark the compliance snapshot as unsaved, and retry only after an explicit or safe idempotent local retry; never report a successful audit save on a failed context save.
- This release does not implement sync, so it creates no network queue or multi-device conflict. Import/restore deduplicates by snapshot UUID. Identical UUID plus identical canonical payload is idempotent; identical UUID with different payload is an integrity conflict, preserved for user/support resolution and never resolved by last-writer-wins.
- Any future sync is blocked until every entity has an E2EE/key, deletion-tombstone, replay, clock-skew and merge policy. If later approved, snapshots/events merge as append-only UUID sets; conflicting payloads are surfaced, never overwritten. This is a prerequisite, not a promise of current behavior.

**7. Privacy and security impact**

- New data is limited to already calculated compliance inputs/results and their jurisdiction/rule-pack provenance. It is sensitive cultivation data, remains on-device, receives the same verified at-rest file protection as the cultivation store, and adds no new network collection or analytics.
- Lock screen, notifications, app switcher, Siri, search, widgets and exports do not reveal snapshot content unless the user explicitly exports through the protected data flow. No notification is required for a rule change; use an in-app banner to avoid exposing status.
- No photos, plant names, room names, free text, location coordinates, household identity, or personal-effect journal data are stored in snapshots. Local analytics remain absent.
- Privacy review is required for snapshot retention, export/delete coverage and the new schema. Attorney review is required before shipping any changed jurisdiction rule content or language that could be read as a legal conclusion. The app continues to say the user must verify current law.

**8. Compliance impact**

- Do not change `ComplianceEngine.counts`, plant-count semantics, possession/canopy arithmetic, alert behavior, or jurisdiction gating as part of snapshot persistence. Regression tests assert byte-for-byte old snapshot preservation and unchanged current calculations for the same inputs.
- Rule pack version changes are visible before a new result is presented as current. The user sees the prior and new pack version, verification/effective dates, source citations, and changed fields. A current-state calculation under a new pack is a new snapshot/event, not an edit to an old snapshot.
- If new rule logic requires a field not present in an old snapshot, show `Not comparable under this rule version`; never derive it from the current grow and pretend it was known historically. Any rule-specific legal ambiguity is sent to counsel, not guessed by engineering.
- Disposition values remain only `consumed at home`, `destroyed`, and `retained`. Plant lifecycle status is not expanded into a transfer/distribution concept.

**9. Accessibility requirements**

- VoiceOver order: screen title/instructions → pack version/date → history row (date, version, summary) → selected detail metrics → citation/source → acknowledgment. Every chart value has a text equivalent; no color-only compliance state.
- Largest Dynamic Type uses vertically stacked metric cards and wrapped citations; table-like comparisons become labeled pairs rather than clipped columns. iPad split view remains navigable with VoiceOver focus order.
- Reduce Motion uses a static banner and immediate list updates; no animated status transition is required.
- Localize dates, numerals, measurements, plural counts, result labels and errors. Keep citations in original legal form; localize explanatory copy only after legal translation review. Accessibility tests include VoiceOver rotor navigation and non-color status cues.

**10. Telemetry**

- No remote telemetry or grow-identifying analytics. Optional local-only QA counters may record snapshot-write success/failure category, schema migration stage, and rule-pack version string only if the user explicitly shares a redacted diagnostic; no jurisdiction code, counts, values, record IDs, names, photos, or journal data.
- Success criteria: migration success without record-count loss; all rule-update notices opened/acknowledged can be measured in internal TestFlight task observation only. Do not add an analytics SDK.

**11. Test plan**

- Unit: deterministic snapshot serialization; append-only immutability; stage/weight/canopy input capture; per-metric outputs; comparable/not-comparable evaluation; pack-diff rendering; UUID idempotency and conflicting-payload detection. Golden tests cover every bundled jurisdiction entry without asserting that its legal text is correct.
- Integration: create representative records, snapshot, mutate current grow, assert old snapshot unchanged and new snapshot appended; update test pack version and assert visible change event; missing-input pack update yields `not comparable`; verify no model/identifier access to personal effect journal or cultivation `JournalEntry` links.
- Migration: migrate copies for every available prior release/fixture; compare all preexisting row counts, IDs, relationships, photo file hashes, harvest dispositions and rule selections; inject interruption at backup, migration, validation and switch stages; verify recoverable source and backup. Test unsupported downgrade behavior on a copy.
- Offline: airplane mode while creating records, changing jurisdiction (without legal interpretation), opening history, upgrading with bundled pack, exporting, restoring and deleting. Assert no network requests and no queued data.
- Compliance regression: same rule/data inputs before and after feature produce identical current levels. Verify pack changes never mutate old snapshot fields, and results that cannot be reconstructed are explicitly not comparable.
- Sensor simulation: not applicable; this feature does not read sensors or alter environment alerts.
- Accessibility: VoiceOver on iPhone/iPad, largest Dynamic Type, Reduce Motion, Switch Control, keyboard navigation on iPad, localization expansion, and chart/text equivalence.

**12. Rollout plan**

- Feature flag `complianceHistoryWriteEnabled` is local and default-off in internal builds until migration validation; enable for internal TestFlight, then a small opted-in external TestFlight cohort, then staged App Store release 1%, 5%, 25%, 50%, 100%. The history viewer can ship read-only only after migration/backup gates; do not show a feature as active if write is disabled.
- No jurisdiction gating based on an unreviewed assumption. Ship rule-pack changes only for jurisdictions whose exact changed content has passed legal review; unchanged jurisdictions retain their prior bundled data/version mapping. Core grow recording stays available offline in every jurisdiction currently supported by the app.
- Rollback criteria: any missing/changed old snapshot, unexpected status delta for unchanged input, migration row loss, failed recovery, older-build store corruption, unsupported jurisdiction mismatch, or data privacy leak halts rollout. Kill switch stops new snapshot/event writes but preserves all prior snapshots and allows export/delete. A later signed app update can disable writes; there is no remote kill switch because no backend exists.
- Gate final release on SAFE-01, verified rollback fixture, legal review of changed rules/copy, privacy sign-off, iOS 18 minimum-OS CI, and a rule-pack checksum/signoff record. Relative estimate: L, with no velocity data available.

**13. Support and documentation**

- Add `Compliance history` help: what fields are recorded, when history begins, why older history cannot be reconstructed, rule-pack versions, how a comparison works, `Not comparable` meaning, and the distinction between an app calculation and legal advice.
- Troubleshooting: if history is missing, do not reinstall/delete data; capture the app/build/rule-pack version, whether migration completed, and a redacted diagnostic. If a displayed current result differs, compare jurisdiction, rule-pack version, the visible counting breakdown, and stored input categories; escalate rule content questions to legal/content owners. For suspected data loss, follow SAFE-01's stop-writes/backup-first process.

## 4. Shared migration plan

1. **Inventory and baseline (before SAFE-01):** Freeze the exact deployed SwiftData model list, relationships, enums, file locations, and supported backup fixtures. Record actual TestFlight/App Store version/build and confirm oldest supported iOS. Do not infer a schema number from Xcode's marketing/build number.
2. **SAFE-01 data controls:** No cultivation schema migration. Introduce backup/export format v2 and continue v1 restore. Ship export/delete model-coverage tests and verified staged restore. Fix fail-open lock and memory-only fallback before any new migration.
3. **Pre-migration gate for COMP-01:** Generate an authenticated, file-protected backup; verify decryption/authentication, model counts, relationship counts, photo references and free-space threshold. Abort migration if any check fails. Keep the source store untouched.
4. **Cultivation schema versioning:** Register the exact current model set as the legacy source schema; define target schema v2 with only additive `ComplianceSnapshot` and `RuleEvaluationEvent`. Add one explicit migration stage. Run it against fixtures from each available released app version and realistic large stores. No field rename, enum reinterpretation, relationship deletion, photo rewrite, or status conversion.
5. **Staged migration and validation:** Migrate a working copy; compare every existing model's row count and stable IDs, relationships, photos and disposition values. Verify the new baseline snapshot is labeled with migration date and that no pre-update history is invented. Swap only after all checks pass.
6. **Rollback:** Preserve the original store and verified backup until the user confirms post-upgrade records/history display. On failure, retain both copies and show recovery; never reset to an empty store. To roll back to an older binary, restore the verified pre-migration store only after explicit confirmation; explain that post-migration compliance snapshots may not be visible in that older binary. Do not silently delete those snapshots.
7. **Export, delete and backup coverage:** Update the model coverage manifest when the new models are added. Backup v2, export, restore, delete-all, migration validation and tests must change in the same release. Unknown versions fail closed. Personal effect journal remains out of scope and is never included by accident.
8. **Sync:** No sync data exists. Do not convert local migration data into a cloud upload or enable the placeholder sync setting. Future sync requires separate schema/versioning and conflict review.

## 5. Dependency and sequencing diagram

```text
Confirm live release/build + iOS 18 support + legal/privacy queue
                         |
                         v
SAFE-01: fail-closed access + recovery + export/backup/delete parity
                         |
             verified v2 backup/restore + coverage tests
                         |
                         v
Freeze legacy SwiftData schema + migration fixtures + rollback rehearsal
                         |
                         v
COMP-01: additive schema v2 + immutable snapshots + visible pack-change events
                         |
              legal review of each changed rule pack
                         |
                         v
Internal TestFlight -> external cohort -> 1% -> 5% -> 25% -> 50% -> 100%

Parallel, not release blockers unless brought into scope:
- sustained environment alerts: existing model/service; separately validate save failures,
  stale readings, irregular intervals, notification privacy and quiet-hour semantics.
- signed remote rules, E2EE sync, sharing/community: blocked pending distinct security/legal designs.
- personal effect journal: not present; privacy review and isolated-store architecture required.
```

## 6. Risk register

| ID | Risk | Likelihood | Impact | Owner | Mitigation |
|---|---|---:|---:|---|---|
| R-01 | Migration or recovery loses existing user records | Medium | Critical | iOS lead | SAFE-01 first; verified backup; staged additive migration; immutable source; model/relationship/photo counts; interruption and rollback fixtures |
| R-02 | App lock exposes records when auth policy is unavailable | Low per review; catastrophic | Critical | iOS/security | Fail closed; remove unlocked fallback; test unavailable/restricted/cancel/error/background paths; block release on any bypass |
| R-03 | Export/delete still omits a newer model or file | High until fixed | High | iOS/data controls | Model-registry coverage test; enumerate photos/caches/notifications/preferences; export and delete all-model integration fixture |
| R-04 | SwiftData store-open failure looks like an empty grow due to in-memory fallback | Medium | Critical | iOS lead | Recovery state instead of memory-only fallback; disable writes until explicit recovery/new-grow choice; error injection test |
| R-05 | Password-protected backup is brute-forceable or corrupt | Medium | High | Security | Versioned password KDF envelope, authenticated encryption, strong parameter tests, old-v1 read-only compatibility, no dependency added |
| R-06 | New compliance status is mistaken for a legal conclusion | Medium | High | Product/legal | No rule logic change in snapshot feature; citation and verification date; legal sign-off on every modified rule/copy; explicit verification duty |
| R-07 | Historical result silently changes after a rule update | Medium | Critical | Compliance owner | Append-only snapshots/events; old bytes immutable; explicit pack diff; `not comparable` for missing inputs; regression tests |
| R-08 | Historical status is fabricated for pre-feature period | Medium | High | Product/data | One clearly labeled post-upgrade baseline only; empty-state copy says prior history was not recorded |
| R-09 | Current rules are stale or legally inaccurate | Unknown | Critical | Legal/content owner | Do not infer conclusions; verify source/citation per jurisdiction; stale badges; block changed packs pending counsel |
| R-10 | iOS 18 users cannot install candidate because project currently targets iOS 26 | Certain if unchanged | High | Release engineering | Confirm product target; lower deployment target and audit API availability if iOS 18 is required; CI on iOS 18 devices/simulators |
| R-11 | Real install base/crash/support signals are unknown | High | Medium | Product/support | Obtain App Store Connect and support baselines before rollout; set numeric crash/rollback thresholds before staged release |
| R-12 | Downgrade/older build cannot open the migrated store or purge new data | Medium | High | iOS lead/support | Fixture-test oldest supported binary; retain verified source backup; explicit recovery/downgrade path; no silent reset |
| R-13 | Exported files or OS backups remain after in-app delete-all | High | High | Privacy/support | State deletion boundary precisely; do not claim external deletion; document Files and device backup controls; legal review copy |
| R-14 | Existing sharing UI is mistaken for functioning secure sharing | Medium | High | Product/security/legal | Label/keep remote sharing disabled; no recipient data path; attorney review and E2EE/scoped-share design before release |

## 7. Open questions and assumptions

1. What is the actual last public/TestFlight marketing version and build, and which historical schema/store fixtures can engineering retrieve? The project values 1.0/1 are placeholders, not proof of a release.
2. What are installed-base size, active-user rate, OS distribution, crash-free rate and support-ticket volume? None are in source; this plan does not fabricate them.
3. Is the app truly required to support iOS 18? Current project target is iOS 26.0. Confirm whether to change the deployment target before planning acceptance-device coverage.
4. Are all 50 state entries plus DC currently exposed to users, or are there release-time jurisdiction gates not represented in source? Confirm with product/legal; source list is not a legal validation.
5. Is `docs/PRIVACY_REVIEW.md` dated 2025-06-14 still current, and which findings are already resolved in production but not in this branch?
6. Are support tickets available for export/restore, lock, compliance-counting, or data-loss complaints? They would refine priority, not change the P0 safety gate.
7. What is the intended support policy for downgrades and TestFlight rollback after a SwiftData migration? The plan assumes no silent downgrade and requires a verified restore path.
8. Which rule changes are currently counsel-reviewed, and who signs off per jurisdiction? No legal conclusion is inferred from the bundled rule data.
9. What backup retention period and free-space threshold are acceptable for staged migration copies? The user must be told before any cleanup; no automatic deletion of the only recoverable copy.
10. Does the current product policy include cultivation-store data in encrypted Apple device backups? The source does not establish exclusion. Clarify policy language and delete guarantees with privacy/legal.
11. Is `ShareGrant` a local draft/placeholder or intended user-facing feature? Repository models/UI exist but no remote sharing transport is evidenced; leave it nonfunctional/disabled until clarified.
12. Is the personal effect journal still a product commitment? It is not implemented in this repo. If approved later, it needs its own encrypted store/key and no relational or metadata linkage to cultivation data.
13. The feature estimates are relative (SAFE-01: M/L; COMP-01: L) because no team velocity or release calendar was supplied.

## 8. Legal and privacy review queue

| Queue item | Applies to | Required gate |
|---|---|---|
| Consumer-health-data applicability, retention, access/deletion rights for cultivation and compliance history | SAFE-01, COMP-01 | Privacy counsel determines applicable state laws and notices before release; engineering does not make legal conclusions |
| Rule summaries, citations, verification date, and any changed state/jurisdiction logic | COMP-01 and any rule-pack release | Attorney/content review of exact source, effective date, computation and user-facing copy per jurisdiction; no rule pack change ships without sign-off |
| Age attestation and age-signal retention | Existing onboarding; outside feature scope | Counsel review before any new age verification or retention changes |
| App-lock / biometric privacy disclosures and passcode requirement | SAFE-01 | Privacy/security review confirms LocalAuthentication data flow and fail-closed disclosure; no biometric template is collected by the app |
| App Store privacy labels, file protection, exports, device backups and deletion claim boundary | SAFE-01, COMP-01 | Privacy review matches actual implementation and distribution configuration before release |
| E2EE, provider-visible metadata, account identity, recovery/deletion/conflict model | Future sync | Blocked: no sync implementation or approved threat model; no E2EE claim until independently tested |
| Recipient access, consultant/peer sharing, third-party disclosure and revocation | Existing sharing UI/future sharing | **Blocked until attorney and privacy review**, identity/access model, E2EE, expiration/revocation, and no-sale/diversion controls are approved |
| Community posts, moderation, age-gating and public display names | Future community | **Blocked until attorney review** of user content policy, moderation operations, escalation, age-gating and privacy; not in release scope |
| Personal effect journal and potential health-data claims | Future personal journal | **Blocked until privacy/legal review**; must remain separate encrypted store/key, local-only, unlinked and excluded from analytics/sharing by design |
| Sensor/third-party integrations or photo/lab analysis | Future features | Privacy/security/legal review before external data, diagnosis-like claim, health claim, or third-party processing is introduced |

No new feature in this plan enables a sale, transfer, distribution, interstate transport, or diversion pathway. Any later proposal that adds such a capability is rejected rather than sent through normal feature review.
