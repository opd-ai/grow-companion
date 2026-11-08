# Data safety and recovery

Status of the local data-safety work (the SAFE-01 slice of the safe-release plan). Everything described here works offline and adds no network, analytics or third-party dependency.

## What the app does now

**Store recovery instead of an empty grow.** `StoreBoot` opens the store at launch. If it cannot be opened, the app shows `StoreRecoveryView` with `Try again` and an explicit `Start a new grow`. It never falls back to an in-memory store, so an unreadable store can no longer look like a grow with no records. Starting a new grow moves the store files into `Application Support/UnreadableStore-<timestamp>` and keeps them.

**One model inventory.** `DataInventory` lists every `@Model` in the schema and provides counts, deletions and human labels for each. Export, backup, restore, delete-all and the tests read the same list, so a model added later cannot stay out of the data controls unnoticed.

**Export format v2.** The JSON archive now carries a manifest (format version, model list, per-model counts, total, whether the journal and photos were included), a producer block (app version, build, `recordSchema: cultivation-v3`, record schema version 3) and the record types that were previously missing:

- training sessions
- feed schedules with their weeks and products
- cycle archives
- paired sensors
- sharing configurations and their access log

Each of those also gets a CSV. Room, plant, strain and environment-reading records now carry their remaining fields (fixture, canopy distance, lineage, rating date, cycle archive, reading source and sensor, master feed schedule).

**Backup envelope v2.** New backups are written as `GROWBACK2`, which records the key-derivation function and its cost inside the envelope (PBKDF2-HMAC-SHA256, 210,000 iterations, 16-byte salt, AES-GCM). Decoding accepts the legacy `GROWBACK1` envelope, so existing backups still restore; an unknown or newer envelope fails closed with an explicit message. `encodeBackup` can still write the v1 envelope so the older format stays covered by tests. Password-protected *exports* use the same v2 envelope.

**Staged restore.** `BackupService.restore` validates the document (structure and, when present, the manifest's counts against the file), rehearses the entire restore — every insert and the save — in a throwaway in-memory store, and only then replaces the device's records. A backup that fails validation or rehearsal leaves the current records untouched. Restore now reinserts every record type, including environment readings, feed events, calibrations, light schedule changes, drying and curing sessions and care reminders, which the previous importer dropped.

Before replacing, the restore dialog states what the backup holds: record count and format version for a v2 backup, or that an older backup carries no record manifest.

**Verified delete-all.** Delete-all walks the inventory, throws instead of swallowing failures, rolls the context back when it cannot complete, and reports the record counts that remain. The completion message says what was removed and that Files copies, device backups and iCloud backups are outside the app.

**Compliance history is part of the data controls.** `ComplianceSnapshot` and `RuleEvaluationEvent` are in the same model inventory, so export, backup, restore and delete-all cover them without a separate path. Export writes `complianceSnapshots` and `ruleEvaluationEvents` sections plus two CSV files; restore reads them back; a v2 manifest can verify their counts. See `docs/COMPLIANCE_HISTORY.md`.

**Cycle goals are part of the data controls.** `GrowGoal` (schema V3) is in the model inventory and in `ExportService.exportedModelNames`, so it is counted, labelled, exported as the JSON `goals` section, verified by the backup manifest, restored and deleted with everything else. Delete-all also clears the widget's shared snapshot and its preference. See `docs/V2_3_CALENDAR_GOALS_WIDGETS.md`.

## Corrections to earlier planning assumptions

These were checked against the source in this branch:

- **App lock already fails closed.** `AppLock.requestUnlock` keeps the cover up when `canEvaluatePolicy(.deviceOwnerAuthentication)` returns false (finding F-03 describes the old behaviour).
- **Export encryption is not raw-password HKDF.** It already used PBKDF2-HMAC-SHA256 with a 100,000-iteration cost (finding F-08); the work above raises the cost for new archives and records the parameters in the envelope.
- **Export/delete coverage was partly fixed.** Treatments, equipment, service history, scouting and environment alerts were already exported; the remaining gap was training, feed schedules, cycle archives, sensors and share grants, plus delete-all missing `CycleArchive`, `SensorDevice`, `ShareGrant` and `ShareAccessLog`, and restore dropping several record types that the backup contained.
- **Deployment target is still iOS 26.0** in every configuration of `project.pbxproj`. The iOS 18 requirement remains an open product decision; changing it is not part of this work.

## Still open

- COMP-01 (versioned SwiftData schema, `ComplianceSnapshot` / `RuleEvaluationEvent`, rule-change review) is implemented and documented in `docs/COMPLIANCE_HISTORY.md`. Release gates that remain: per-pack legal review of any *changed* rule-pack content (the shipped copy is reviewed, 2026-11-07), staged rollout, privacy sign-off, and migration fixtures from every released build (none can be retrieved from this repository, so the migration test uses a locally created V1 store).
- Legal review of the shipped copy and rule pack: cleared 2026-11-07 (review register in `docs/ROADMAP.md` section 1.1). Per-change review still applies to any changed rule pack or legal copy. Privacy sign-off, staged rollout and the iOS 18 decision from the plan remain open.
- The test target compiles with the share, data-safety and compliance-history suites. CI runs the full suite on an iPhone 17 simulator; this environment has no simulator, so the tests have been compiled here but not executed.
