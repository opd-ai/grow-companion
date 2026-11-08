# Compliance history and rule-change review

Status of COMP-01, the second phase of the safe-release plan. Everything here
works offline, stores no plant or room names, and adds no network, analytics or
third-party dependency.

## What ships

**An append-only record of each calculation.** Whenever the displayed
compliance calculation changes (plant count or stage, retained dry weight,
occupied canopy, jurisdiction, warning threshold or applied rule pack), the app
writes a `ComplianceSnapshot`. The snapshot keeps the jurisdiction code and
state name, the pack version and verified date, the citation and primary source
link, per-stage plant buckets, retained grams, canopy square metres, the plant,
possession and canopy limits, the warning threshold, and the per-metric result.
The first snapshot is labelled as the point where history begins; it never
claims to reconstruct a result from before the update.

**No duplicate writes.** A SHA-256 fingerprint over the same inputs, the pack
version and the snapshot schema version is compared with the newest snapshot.
An unchanged garden writes nothing, so opening Home or Rules repeatedly does not
grow the history.

**Rule-change review.** When a saved snapshot carries a different pack version,
the app appends one `RuleEvaluationEvent` per snapshot. The event records the
old and new pack versions and verified dates, the changed fields with their
labels, per-metric previous and current results, a short summary, the citation,
and the grower's acknowledgment timestamp. The event identifier is derived from
the snapshot ID and the new pack version, so the same review is never appended
twice, even across launches.

**Honest comparison.** The comparison re-evaluates the stored inputs, not the
current garden:

- Counted plants are recomputed from the stored stage buckets under the new
  rule's counted stages and clone setting.
- Stored flower is compared against the new possession limit.
- Canopy is only marked comparable when the rule's counted stages, clone
  setting and cultivable flag are unchanged, because the stored canopy total was
  derived from the old occupancy set.
- A snapshot from a newer snapshot schema, a newer pack version than the build
  carries, or a jurisdiction missing from the pack is recorded as
  `not comparable`, with no inferred result.

**Surfaces.** Home and Rules show a rule-update banner while a review is
unacknowledged. The review sheet shows the version change, verified dates, a
was/now comparison of each changed limit, each saved calculation's result, and
the citation. Acknowledging records that the review was seen; it changes no
snapshot and is not a legal acceptance. The Rules snapshot card links to
`Compliance history`, a list of saved calculations with a detail view for each.
The card says whether the current calculation is saved, or that history could
not be saved, instead of claiming a write that failed.

## Data model and migration

| Model | Fields |
| --- | --- |
| `ComplianceSnapshot` | stable UUID, captured time, jurisdiction code and state name, pack version and verified date, citation and URL, counted plant total, stage buckets, retained grams, canopy square metres, limits, warning threshold, cultivable/counted stages/clone/scope inputs, per-metric levels, fingerprint, baseline flag, schema version |
| `RuleEvaluationEvent` | stable UUID derived from the snapshot and new pack version, prior snapshot UUID, prior and new pack versions, prior and new verified dates, jurisdiction, evaluated time, comparable/not-comparable outcome, changed fields, per-metric comparisons, citation and URL, acknowledgment time, schema version |

The store is now explicitly versioned:

- `CultivationSchemaV1` freezes the exact model set that shipped with the
  unversioned store.
- `CultivationSchemaV2` adds only the two compliance models.
- `CultivationMigrationPlan` has one lightweight additive stage from V1 to V2.
  No existing model, relationship, identifier, photo or value is rewritten.
- `StoreBoot` opens V2 with the migration plan. An unreadable store still routes
  to recovery and never to an empty in-memory substitute.
- A test builds a V1 store on disk, inserts records, then opens it with the V2
  plan and asserts the records survive and the new models are empty.

Export and backup identify the schema as `cultivation-v2` with schema version 2.
No backup envelope bump is needed: v2 archives carry the new sections, and the
restore path reads them. A v2 manifest can verify the counts of both new model
types.

## Data controls

- `DataInventory` includes both models, so the coverage test fails if either is
  missing from export or delete.
- Export JSON adds `complianceSnapshots` and `ruleEvaluationEvents`, plus
  `csv/compliance_history.csv` and `csv/rule_change_reviews.csv`.
- Backup restore reinserts both record types, including their stage buckets,
  changed fields and metric comparisons. Malformed sections are rejected by
  validation before anything is touched.
- Delete-all removes them with the rest of the inventory.

## Privacy and legal boundaries

- Snapshots contain only inputs the evaluator already used and the resulting
  status. No plant names, room names, free text, photos, coordinates, household
  identity or journal entries are stored.
- Snapshots are ordinary cultivation records: local only, behind app lock, and
  included in export and delete. They are not personal effect journal data.
- The review copy distinguishes the app's calculation from legal advice and
  tells the grower to verify current law. Acknowledgment is not legal acceptance
  and never changes an old result.
- No remote pack is fetched, no notification is sent for a rule change, and no
  rule content is changed by this phase. A rule-pack version bump also needs
  attorney review of the changed jurisdiction content before release.

## Accessibility

- History rows read as date, jurisdiction, pack version, counted plants and
  status in one VoiceOver element.
- The rule review reads changed fields as "was X, now Y" and labels each metric
  result with text, not colour alone.
- Screens use scrolling layouts and wrapped labels so the largest Dynamic Type
  sizes do not clip counts or warnings.
- Sheets are dismissible with a labelled Close/Done button and push detail
  navigation stays inside the sheet's own navigation stack.

## Tests

`Grow CompanionTests/ComplianceHistoryTests.swift` covers:

- snapshot fields, baseline flag and stage buckets
- duplicate suppression for an unchanged calculation
- a second snapshot after a change
- immutability of an earlier snapshot after the garden changes
- rule-change comparison, changed plant limit, per-metric results, idempotent
  re-evaluation and acknowledgment
- unsupported snapshot schema and a newer stored pack being not comparable
- versioned schema membership and a real V1-to-V2 on-disk migration
- export, manifest counts, backup envelope and restore validation coverage
- rejection of a malformed compliance section

The app target and the test target compile here. CI runs the suite on an iPhone
17 simulator. This environment has no simulator, so the tests have not been
executed locally.

## Release gates still open

- Migration fixtures from every released build: none are available from this
  repository, so the migration test uses a locally created V1 store.
- Attorney review of any changed rule-pack content or user-facing copy.
- Privacy sign-off for snapshot retention and the export/delete copies.
- A staged rollout with record-count and migration validation, and the iOS 18
  deployment-target decision from the safe-release plan.
- Localisation of the new interface copy beyond the current English build.
