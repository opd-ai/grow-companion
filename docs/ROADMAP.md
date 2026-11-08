# Grow Companion — product roadmap and delivery reference

This document completes Tier 3 (the v2+ differentiators) and records Tier 4,
the user stories, the high-level data model, the MVP screen map, the technical
risks and the success metrics. It is the shared reference for design,
engineering and content work; the app itself is the source of truth for what
has shipped.

Rule pack referenced throughout: **2025.05.1**, verified 15 May 2025.

---

## 1. Where the product stands

Grow Companion is a private, on-device record for a personal home grow. It has
no account, no marketplace and no network dependency. Every record lives in a
SwiftData store under complete file protection, and photos are re-encoded on
import so location metadata never survives.

| Capability | State | Lives in |
| --- | --- | --- |
| Age attestation, jurisdiction, residence and experience onboarding | Shipped | `Views/Onboarding/OnboardingFlow.swift` |
| Plain-language rules with citation, primary source and verified date | Shipped; bundled pack only | `Rules/`, `Views/Rules/RulesDetailView.swift` |
| Home compliance ring, counting breakdown, task list | Shipped | `Views/Home/HomeView.swift`, `Services/ComplianceEngine.swift` |
| Rooms, canopy, light type, wattage and room filtering | Shipped | `Views/Rooms/RoomEditorView.swift`, `Views/Home/HomeView.swift` |
| Light schedules with flowering-plant warning and override log | Shipped | `Views/Rooms/LightScheduleEditor.swift`, `Services/LightSchedule.swift` |
| Environment, feed, runoff and calibration logging with targets and drift | Shipped | `Services/CareLog.swift`, `Views/Care/` |
| Reminders, local notifications, per-category priority, quiet hours | Shipped | `Services/CareNotifications.swift`, `Services/NotificationSettings.swift` |
| Journal with notes, observation tags and photos | Shipped | `Views/Journal/`, `Services/PhotoStore.swift` |
| Harvest, drying, curing, burping and yield (grams per watt, dry-to-wet) | Shipped | `Views/Harvest/`, `Services/HarvestLog.swift` |
| Strain library, breeder figures, observed flowering time, ratings | Shipped | `Views/Strains/`, `Services/StrainInsights.swift` |
| Training sessions and lineage | Shipped | `Views/Plants/TrainingSessionEditor.swift`, `Models/TrainingSession.swift` |
| Treatments and withdrawal periods | Shipped | `Views/Plants/TreatmentSection.swift`, `Models/Treatment.swift` |
| Equipment and service reminders | Shipped | `Views/EquipmentView.swift`, `Models/Equipment.swift` |
| Plant and room scouting checks | Shipped | `Views/Plants/ScoutingCheckSection.swift`, `Models/ScoutingCheck.swift` |
| Weekly recap, room comparison and cycle archive | Shipped | `Views/Home/` |
| Password-protected local backup and restore | Shipped | `Views/Settings/BackupView.swift`, `Services/BackupService.swift` |
| Store recovery, verified export/backup/restore and delete-all | Shipped | `Services/StoreBoot.swift`, `Views/StoreRecoveryView.swift`, `Services/ExportService.swift`, `Services/DataInventory.swift` |
| Protected, recipient-scoped share files | Shipped (file based; encryption not independently reviewed) | `Services/SecureEnvelope.swift`, `Services/SharePayload.swift`, `Services/SharePackageService.swift`, `Views/Sharing/` |
| Face ID lock, privacy screen, export and delete-all | Shipped | `Services/AppLock.swift`, `Services/PrivacyCover.swift`, `Views/Settings/` |
| Privacy review and remediation of local security findings | Shipped | `docs/PRIVACY_REVIEW.md`, protected local services |
| Immutable compliance history and rule-change review | Shipped | `Models/ComplianceSnapshot.swift`, `Models/RuleEvaluationEvent.swift`, `Services/ComplianceHistory.swift`, `Views/Compliance/` |
| Garden timeline and Quick Log | Shipped | `Services/GardenTimeline.swift`, `Views/Garden/GardenTimelineView.swift`, `Services/QuickLog.swift`, `Views/QuickLog/QuickLogSheet.swift` |
| Photo timeline, side-by-side compare and PDF grow report | Shipped | `Services/PhotoTimeline.swift`, `Views/Garden/PhotoTimelineView.swift`, `Services/GrowReport.swift`, `Views/Settings/GrowReportView.swift` |
| Per-cycle grow goals: dry yield, flowering time and logging completeness | Shipped | `Models/GrowGoal.swift`, `Services/GrowGoals.swift`, `Views/Home/GrowGoalsSection.swift` |
| Grow calendar with explicit reminder rescheduling | Shipped | `Services/GrowCalendar.swift`, `Views/Home/GrowCalendarView.swift` |
| Home Screen and Lock Screen widget with privacy-safe defaults | Shipped | `Grow CompanionWidgetExtension/`, `Services/WidgetSnapshot.swift` |
| Light-distance guidance with a grower-set target and re-measure prompts | Shipped | `Services/LightDistanceGuidance.swift`, `Views/Rooms/LightDistanceView.swift` |
| Breeder reference library with claimed figures kept apart from your results | Shipped | `Models/BreederProfile.swift`, `Services/BreederLibrary.swift`, `Views/Strains/BreederProfileView.swift` |

The shipped navigation and current feature surfaces are recorded in section 6.2.
Future cloud, hardware, extension and community features remain explicitly
planned rather than implied as implemented.

---

## 1.1 Privacy architecture

Grow Companion is a local record and nothing else. The boundary is part of the
product, not a stage it passes through:

- **No account and no server.** There is no sign-in, no identifier and nothing to
  pair. A record exists on the device that made it.
- **No network request of the app's own.** No CloudKit, no URL session, no remote
  rule or content download. Links to a primary source open in the browser, which
  is outside the app.
- **No location access.** The grower picks a state from the bundled list. The app
  never asks for permission, never asks Core Location for a position and never
  reverse-geocodes one.
- **No analytics, advertising, crash reporter or third-party SDK.**
- **Sharing is a file the grower writes and sends themselves.** It is encrypted
  and signed for one recipient, read-only on the other side, and there is no
  transport in the app.

These invariants are enforced by `Grow CompanionTests/PrivacyBoundaryTests.swift`,
which scans the app sources and the Info.plist for a network, CloudKit or Core
Location API and fails the suite if one appears. `docs/PRIVACY_ARCHITECTURE.md`
records the same boundary in product terms.

The legal and safety copy the app shows is part of this boundary, not a review of
it: no sale, gift, transfer or diversion pathway; no health, diagnosis or
treatment claim; harvest dispositions limited to retained, consumed at home and
destroyed; and the standing statement that the grower must verify current law.
Spanish legal and rule text stays English, so there is exactly one reviewed
version of it.

---

## 2. Tier 3 — v2+ differentiators

Tier 3 extends what is already shipped. Two items are partly in the product
(the strain library and the rule pack); the rest are new local services and
surfaces. Each section states the value, the flow, the data and storage, and the
dependencies and risks.

**Privacy boundary.** Every item below ships inside the boundary in section 1.1.
A feature that needs an account, a server, a sync engine, a remote download or a
location lookup is not built, not deferred and not awaiting a review: it is
outside the product, and the sections that used to describe one now record that.

### 2.1 Advanced photo analysis — validation and governance

The capture and suggestion flow ships with the earlier work; the remaining
work is validation and governance. A suggestion is only acceptable if it is
measured against a labelled test set, carries its model version, and is never
written to a plant record without the grower's confirmation.

**Validation**

- Build a labelled corpus per class and per capture source. Two sources must be
  reported separately: handheld phone photos and microscope images.
- Proposed class list: nutrient deficiencies (N, P, K, Mg, Fe), pest damage,
  light stress and bleaching, heat and water stress, mould and bud rot,
  trichome ripeness mix, and pre-flower sexing.
- Report per-class precision and recall, the most common confusion pairs, and
  accuracy per capture source. No single headline accuracy figure.
- Hold out images from growers and gardens not present in training. Re-label
  the test set for every model version, and print the model version and dataset
  version next to every reported number.
- Calibrate confidence: a "likely" suggestion should be right more often than
  a "possible" one, and the UI copy should mirror that difference.

**Validation thresholds**

These are the thresholds a suggestion must meet; they are targets, not product
promises.

| Measure | Threshold |
| --- | --- |
| Phone-photo precision, top five classes | ≥ 0.90 |
| Phone-photo recall, any class surfaced | ≥ 0.75 |
| Microscope trichome ripeness agreement | ≥ 0.85 |
| Suggestions a grower marks wrong | ≤ 1 in 10 |
| Suggestions saved without confirmation | 0 |
| Photo data leaving the device | 0 |

**Governance**

- Publish a model card with the version, training-data summary, per-bucket
  results, known failure modes and review date.
- Show the model version and a plain confidence label on every suggestion.
- Require confirmation before anything is written to a plant record. Show the
  suggested observation as a proposal, and let the grower edit the text before
  saving.
- Keep corrections on the device. There is no "contribute corrections" option:
  nothing leaves the phone.
- Model weights ship in the app bundle and inference runs on device. No photo,
  crop or embedding leaves the phone.
- Treat safety-adjacent classes (mould, pests, ripeness) as guidance, never as
  a verdict: copy must tell the grower to inspect the plant, and must never
  read as a diagnosis.
- Change control: every model release runs the regression suite, records the
  result, and keeps the previous version available for rollback. A model that
  misses a threshold does not ship.

**Flow**

Plant or journal photo → "Analyse" → on-device suggestion with model version
and confidence → grower reviews, edits or dismisses → confirmation writes an
observation note or tag to the plant. Dismissals are stored locally as
corrections.

**Data and storage**

Model weights in the bundle; corrections and model history on device; no cloud
upload, no analytics. Delete-all removes corrections with the rest of the store.

**Risks**

Model drift between app versions, false confidence, label drift in the test
set, and growers treating a suggestion as a diagnosis. Mitigations are the
versioned model card, the confirmation step, the confidence copy and the review
cadence.

### 2.2 Light-distance guidance

**Value**

Light too close bleaches and burns the canopy; light too far wastes energy and
loses yield. Guidance at each stage keeps the fixture at a useful distance as
plants grow and after training sessions.

**Flow**

Room → "Measure distance" → point the camera at the canopy (LiDAR on supported
models) or type the measurement → confirm the reading → the app shows the
target range for the current stage and the fixture's cited recommendation →
schedule a re-measure, especially after a training session that changes canopy
height.

**Target data**

- Per-fixture targets for vegetation and flower, plus a seedling factor, each
  with a source and a review date. Manufacturer targets vary, so the app must
  cite the source for the figure it shows rather than imply a universal rule.
- Targets are editable when a grower's own fixture or manufacturer sheet
  differs, and the edited target is labelled as grower-set.
- Unit-aware entry and display, matching the rest of the app.

**Data and storage**

Distance readings, the fixture model and the stage-at-reading are stored on
device. Depth data is processed in memory and never saved; only the resulting
distance is kept.

**Dependencies and risks**

LiDAR is unavailable on many iPhones, so the manual path must be complete and
equally good. Re-measure prompts depend on the training log, which does not
exist yet. Manufacturer guidance is not a substitute for the grower's own
observations.

**Shipped.** `Services/LightDistanceGuidance.swift` holds the guidance as pure
value types: the cited band per fixture and stage, the seedling and vegetative
factors, the grower's target, the status of a reading, and the re-measure rules.
`Views/Rooms/LightDistanceView.swift` measures (LiDAR where it exists) or takes
a typed distance, shows the stage band with its source and review date, offers a
grower-set target labelled as the grower's own, and saves the distance, its
method and the stage at reading on the room. The room dashboard carries the
same card, with a re-measure prompt titled by its reason: no measurement yet, a
stage change since the reading, training recorded after it, or a reading older
than 14 days. The training dependency is met by `Models/TrainingSession.swift`.
Both entry paths are complete and unit-aware: metric shows centimetres,
imperial inches, and a typed value is read in the grower's own unit. Depth
frames are read in memory and never saved. Tests cover the bands and factors,
grower targets, status boundaries, every re-measure reason and its order, unit
parsing and the stored room fields. See `docs/LIGHT_DISTANCE_GUIDANCE.md`.

### 2.3 Genetics and breeder library

**Value**

Growers can compare how a cultivar performed in their own rooms with what the
breeder claimed, which is what makes it easy to decide what to repeat.

**Flow**

Strain detail → breeder and lineage section → "Your results", which compares
observed flowering time, yield per watt and the grower's rating with the
breeder's claimed figures.

**What ships today**

The strain library already holds a free-text breeder, type, expected flowering
weeks, notes, the grower's observed flowering time and ratings. This item
extends it:

- Breeder profiles as reference entities (name, notes, links), so several
  strains can point at the same breeder.
- Parent lines and pedigree, with the caveat that lineages are disputed.
- Claimed figures held apart from the grower's results, so the comparison is
  explicit rather than implied.

**Data and storage**

Breeder and pedigree data are read-only reference content, bundled now and
updated through the same signed content pipeline planned for the rules. User
results stay on device.

**Dependencies and risks**

Breeder claims are unverified marketing data. Every breeder figure is labelled
"claimed", and the app never presents potency or genetic-test claims as
verified results.

**Shipped.** `Models/BreederProfile.swift` and `Services/BreederLibrary.swift`
hold the reference as values: a profile for every breeder in the bundled
template catalogue (summary, notes, an https link only where one is known, a
source and the shared review date), a lineage claim per cultivar and breeder
pair, and the comparison between a claimed window and the grower's own finished
cycles. `BreederLibrary.key(for:)` folds case, accents, punctuation and spacing,
so several strains that spell a breeder differently point at one profile.
`Views/Strains/BreederLibraryView.swift` and `BreederProfileView.swift` are
reached from the strain library and from the strain detail's breeder card; the
profile screen lists the grower's strains with the claim, their observed average
and a sentence comparing the two. Lineage belongs to a cultivar rather than a
breeder, and only the three claims the app already carried are repeated, with
Jack Herer marked disputed. The strain detail labels the flowering window
"Claimed", and the editor offers the bundled breeders as suggestions. Nothing
new is stored, so export, backup, restore, the data inventory and delete-all are
unchanged. Tests cover matching, profile coverage, every lineage claim, the
comparison copy and the product-claim limits. See `docs/BREEDER_REFERENCE.md`.
A stored, grower-editable breeder profile and the signed content pack that would
replace the bundled one remain unbuilt.

### 2.4–2.7 Outside the product

Consultant sharing over iCloud, community and Q&A, a personal effect journal and
cloud sync are not features of this app and are not waiting on a review. Each one
needs an account, a server or a cloud store, or a second store with its own
authentication policy, and each would weaken the guarantee in section 1.1 that
nothing leaves the device.

The local answer the app already ships for the first of them is the share file: a
grower chooses the categories, writes an encrypted and signed file, and sends it
themselves. The recipient opens a read-only copy. There is no server, no account
and no live link between devices.

All four remain outside the product. The privacy screen says so in the app.

### 2.8 Educational library

**Value**

Beginners learn the reasoning behind a task, and experienced growers can
refresh a specific topic.

**Flow**

Library → topic → lesson with a checklist → "Apply to my grow" opens the
relevant room or plant.

**Content model**

Cultivation fundamentals, integrated pest management, curing practice and legal
compliance. Every lesson shows its review date. IPM lessons avoid specific
product recommendations; legal lessons cite the rule-pack version they were
written against.

**Data and storage**

Lessons are bundled read-only content. There is no remote content pipeline:
the app makes no network request, so an update arrives with an app update.
Reading progress is stored on device.

**Dependencies and risks**

Outdated advice, and advice that conflicts with product labels. Each lesson
shows its review date, and content review is scheduled with the rule-pack
review.

---

## 3. Tier 4 — future and nice-to-have

These features are useful but low priority. Each one should wait until the core
experience is stable, and several require validation before they ship.

| Feature | Description | Why it waits | Data and storage | Key risk |
| --- | --- | --- | --- | --- |
| SCROG layout planner | Interactive net-and-canopy planner for placing branches in a screen grid. | Depends on the training log and the light-distance feature. | On-device layout records. | Visual complexity on iPhone screens. |
| Mac companion | Mac Catalyst or native app for detailed reports and bulk data entry. | Needs a stable data model, and there is no sync layer to carry records between devices. | Local only; no sync. | Doubles the test surface. |
| Home automation bridges | Connectors for Home Assistant and similar hubs for advanced automation. | Would add a network connection the product does not have. | None: outside the privacy boundary. | Credential exposure through third-party hubs. |
| CO2 control automation | Schedules or triggers CO2 supplementation with safety limits. | Requires validated sensor data and a safety design. | On-device schedule. | Safety risk if sensors fail; requires interlocks. |
| Lab PDF extraction with OCR | Automated extraction of values from lab reports. | Extraction errors are dangerous, so manual confirmation must be proven first. | Extracted values on-device. | Misread results. |
| Strain comparison and cultivar analytics | Side-by-side charts across cultivars using the user's own data. | Needs enough history to be meaningful. | On-device. | Small-sample conclusions presented as facts. |
| Household profiles | Separate profiles on one device for shared grows. | Adds permission complexity. | Per-profile encrypted stores. | Access-control bugs. |
| visionOS or Vision Pro view | Spatial room view with live sensor overlays. | Small installed base. | On-device. | Limited value relative to effort. |
| Additional languages | Expanded localization beyond the launch set. | Depends on rule coverage in each language. | Bundled strings. | Translation accuracy for legal text. |

Tier 4 is reviewed once Tier 3 is complete. Nothing here may add an account, a
server or a network request; that boundary is fixed for the product.

---

## 4. User stories and acceptance criteria

Each story lists its state in the shipped app: **Shipped**, **Partial** (some of
the criteria are met), or **Planned**.

### 1. Confirm my plant count is legal before I plant — Shipped

As a new grower, I want to see whether adding a plant keeps me within my
jurisdiction's limit, so I don't exceed it by accident.

- Given my jurisdiction is set, when I add a seedling, then the app shows the
  new count against the limit before saving.
- If the addition would exceed the limit, the save button is replaced with an
  explanation of the rule and the counting method used.
- The counting method is shown beside the number, including whether seedlings
  or clones count.

*Shipped:* Add Plant shows a count card before saving — the counted total now,
the total after saving, the jurisdiction's limit, the rule's level and its
counting note — computed by `QuickLogService.countPreview(addingStage:…)` without
writing anything. When the addition would cross the limit the Save action is
withdrawn, the card turns amber and names the rule, its counting method and its
citation, and the save path refuses the write even if it is reached another way.
The same check already guards a stage change in Quick Log and on plant detail,
and the compliance ring, counting note and "How this is counted" breakdown
remain the live view of the same calculation. Tests cover a counted seed, a
clone in a rule that excludes clones and one that includes them, the over-limit
case, a rule with no numeric limit, destroyed plants and a non-cultivable
jurisdiction.

### 2. Know when a rule has changed — Shipped

As a grower, I want to be told when the rules for my area change, so I can
adjust my grow without surprises.

- When a new rule pack is verified and applied, the user sees a notice that
  identifies only the rules that changed.
- If my current status changes (for example, I am now over a limit), I receive a
  time-sensitive notification.
- If the rule pack is more than 90 days old, a visible "unverified" badge
  appears on every rule it affects.

*Shipped:* the pack carries its version and verified date, and each rule shows a
"Needs re-verification" pill once it is more than 90 days old. The app records
an append-only snapshot of every calculation it displays, and when a bundled pack
version differs it appends a review event that names the changed fields, their
citations and a per-metric comparison, which the grower acknowledges explicitly.
When a calculation moves towards a limit — within limits to close, close to over,
or straight to over — `Services/ComplianceStatusNotifier.swift` schedules one
time-sensitive notification under the new *Compliance status* category, so the
grower can turn it off or change its priority like any other category. The first
calculation is a baseline and never notifies, returning inside the limits is not
announced, and the copy names the two levels, carries no plant or room name and
says the figure is an estimate rather than legal advice. Tests cover the baseline,
every worsening pair, improvements, unchanged and unknown levels, the copy and
the per-snapshot identifier. Remote signed packs and per-change legal review of
any future pack content remain the remaining work; the shipped pack was reviewed
on 2026-11-07 (section 1.1).

### 3. Log a watering in under five seconds — Partial

As a grower with wet hands in the grow room, I want to log a watering from my
Watch or with Siri.

- A Watch complication or Siri phrase logs a watering for the selected room with
  the current time.
- The entry appears in the plant timeline within 2 seconds of saving.
- If the room is ambiguous, the app asks one clarifying question and does not
  guess.

*Shipped — Siri and Shortcuts.* `Intents/LogWateringIntent.swift` exposes a
"Log a watering" app shortcut with an optional room, and
`Services/WateringShortcut.swift` decides which room it lands in: an explicit
room wins, then the room the app remembers, then the only room there is — and
several rooms with nothing to choose between them is a question that names them,
never a guess. The watering is written through the same service the Quick Log
sheet uses, so the timeline, the reminders and the counts see it immediately,
and nothing is written when the room is missing or unknown. Seven tests cover the
explicit, remembered, single-room, ambiguous, unknown and empty cases plus the
resolver on its own.

*Remaining:* the Watch app and complication, which need a Watch target that the
current project setup does not have, and a device check of the Siri phrases and
the shortcut's permission on a real iPhone.

### 4. Get warned before my room leaves its range — Shipped

As a grower, I want an alert when temperature or humidity leaves the target
range for my stage, so I can act before plants are damaged.

- A threshold alert fires when readings remain outside the range for a
  user-set duration (default 10 minutes), which prevents alerts on brief spikes.
- The alert names the room, the reading, the target range, and a suggested
  action.
- Alerts respect quiet hours, except for alerts the user has marked critical.

*Shipped:* `EnvironmentAlertService.excursions` walks the room's readings in
date order and only treats a run as sustained when consecutive out-of-range
readings are no more than the threshold apart, so a single spike — or two
out-of-range readings separated by hours of no measurement — never raises an
alert. `evaluate` records one alert per excursion, never re-reports an older
one, and schedules the notification with the room, the reading, the target and a
suggested action that matches the direction of the excursion. Quiet hours come
from the readings category's priority, so marking that category critical is the
grower's way to let an alert through. The room's threshold stays editable on the
room screen (`sustainedAlertMinutes`, default 10). Tests cover a brief spike, a
sustained run, a long gap, a return to range, humidity measured separately and
the direction of the suggested action.

### 5. Track a plant from seed to storage — Shipped

As an experienced grower, I want each plant's stage history and every related
event in one timeline, so I can review what happened.

- Each stage change is stored with a timestamp, and a stage can be backdated with
  a reason.
- The timeline includes feeds, environmental alerts, training events, and photos
  linked to the plant.
- Deleting a plant offers to keep or delete its history, and it never deletes
  batch records without confirmation.

*Shipped:* stage changes are timestamped, the backfill editor records a missed
transition with a reason, and plant detail gathers the stage history, training,
treatments, scouting checks, photos and harvest record for one plant. The garden
timeline now merges feeds, readings and environment alerts as well as the eleven
record types it already carried, and filters by room or plant. Removing a plant
asks first and offers *Archive and keep history* — every record stays readable
and the plant leaves the active garden through a cycle archive — or *Delete
plant and its history*, which removes the plant and its stage, training,
treatment, scouting and drying records while journal entries stay without a
plant link. `PlantRemovalService` performs both outcomes with explicit errors,
and its summary feeds the confirmation. Tests cover archiving, reusing an
archive, deletion keeping the journal, the summary counts and the environment
alert entry in the timeline.

### 6. Compare yield per watt across rooms — Shipped

As an experienced grower, I want to compare yield per watt across rooms and
cultivars, so I can decide where to invest.

- Each harvest shows wet weight, dry weight, dry-to-wet ratio, and watts used,
  with the source of the watt figure labeled as nominal or measured.
- A chart compares rooms and cultivars across the same time range.
- Figures with fewer than three harvests display a "limited data" label.

*Shipped:* Home opens a read-only room comparison report with room selection,
date range, plant count, out-of-range readings, feeds and waterings, training
sessions, dry yield and grams per watt. Missing values are shown as "No data"
and the report never infers a value.

### 7. Hear a clear explanation of why a rule applies — Partial

As a beginner, I want the rules explained in plain language, so I understand
what they mean for my grow.

- Each rule shows a plain-language summary, the official citation, the effective
  date, and the last verification date.
- A "Show full text" option displays the rule as published.
- The app states that the user is responsible for verifying current law before
  acting on any rule.

*Today:* every rule card shows the plain-language summary, citation, primary
source link, effective date and last verified date, with the federal notice and
verification duty always visible. The full statutory text is not embedded; the
app links to the primary source instead.

### 8. Keep my data private if my device is lost or shared — Shipped

As a grower, I want my data protected by Face ID and a privacy screen, so others
cannot see it.

- When app lock is enabled, the app requires authentication after the chosen
  grace period.
- The app switcher shows a neutral image instead of grow content.
- Notifications on a locked screen show no plant names, room names, or
  measurements.

*Shipped:* Face ID with the device passcode as fallback, an immediate, 1-minute
or 5-minute grace period, a window-level neutral cover behind the app switcher,
and notification copy that never names a plant or room.

### 9. Export or delete everything — Shipped

As a grower, I want to take my data with me or erase it completely, so I control
my records.

- Export produces a ZIP archive with CSV and JSON files and the photos, and it
  excludes the personal journal unless I select it.
- Delete-all requires a typed confirmation and lists what will be removed,
  including cloud data and sensor history.
- After delete-all completes, the app verifies that no local or cloud records
  remain and displays a confirmation.

*Shipped:* the export ZIP contains JSON, CSV files and optional journal photos,
with optional password encryption, and delete-all requires a confirmation plus a
typed phrase and lists every record type. There is no cloud data to verify
today; the app returns to onboarding after erasing rather than showing a
separate "no records remain" screen.

### 10. Share read-only access with my consultant — Shipped, as a share file

As a grower working with a consultant, I want to share selected rooms for a set
period, so they can review my data without full access.

- I select which categories to share, and the journal and any location text are
  unavailable to select.
- The share expires on the date I set, and I can revoke it at any time; the file
  is encrypted and signed for one recipient.
- The recipient opens a read-only copy, cannot export, edit or delete data, and
  there is no server, account or live link between devices.

*Shipped:* `Views/Settings/SharingView.swift`, `Services/SharePackageService.swift`
and `Services/SecureEnvelope.swift`. The file is written by the grower and sent
outside the app, which is the only sharing this product has.

### 4.11 Shipped v1.x additions

The following capabilities were added after the original MVP stories and are
part of the current app:

- **Scouting checks — Shipped:** plant or room checks with finding chips, a
  backdated date, optional note and protected photo, shown newest first on
  plant detail and room dashboards.
- **Treatments and withdrawal — Shipped:** plant or room treatment history with
  product, dose, date, note and optional withdrawal end date.
- **Equipment and service reminders — Shipped:** room equipment, service
  interval, due/overdue state and service history.
- **Weekly recap — Shipped:** a read-only date-stepped summary of stage moves,
  feeds and waterings, out-of-range readings, journal/photos and upcoming tasks.
- **Encrypted backup and restore — Shipped:** password-protected local backup
  with optional journal photos, password validation, replacement warning and
  local restore; nothing is uploaded.
- **Cycle archive — Shipped:** completed plants can be grouped into a named
  archive without deleting history, and reopening requires confirmation.

---

## 5. High-level data model

The model separates cultivation data (encrypted on device, optionally synced),
the personal journal (separate store, never synced by default), reference
content (read-only, updated remotely), and sharing metadata.

### 5.1 Target model

```text
CULTIVATION STORE (encrypted, optionally synced via E2E)
Grow               id, name, startDate, status, jurisdictionCode
Room               id, growId, name, type(indoor|outdoor), canopyArea,
                   lightType, lightWattage, wattageSource(nominal|measured)
Plant              id, roomId?, strainId, batchId?, source(seed|clone|cutting),
                   stage, stageStartedAt, isMother, countsTowardLimit
StageEvent         id, plantId, fromStage, toStage, at, backdatedReason?
Strain             id, name, breederId?, expectedFlowerWeeks, userRating, notes
Breeder            id, name, claimedData(ref to reference content)
JournalEntry       id, at, text, photoIds[], linkedPlantIds[], linkedRoomIds[]
Photo              id, fileRef, thumbnailRef, takenAt, exifStripped, tags[]
Reading            id, roomId, sensorId?, at, tempC, rh, co2?, vpdKpa(derived),
                   ppfd?, source(manual|sensor)
Threshold          id, roomId, metric, min, max, durationMinutes, priority
FeedEvent          id, plantId|reservoirId, at, volumeL, phIn, phOut, ecIn,
                   ecOut, runoffPh?, runoffEc?
Reservoir          id, roomId, capacityL, currentL, lastFillAt
TrainingEvent      id, plantId, method, nodesAffected, photoId?, at
CuttingEvent       id, motherPlantId, count, at, cloneBatchId
CloneBatch         id, cutCount, rootedCount?, status, countsTowardLimit
ScoutingCheck      id, roomId|plantId, checklistType, findings[], at
Treatment          id, plantId, productName(user-entered), dose, at,
                   withdrawalDays?, notes
HarvestEvent       id, plantId|batchId, at, wetG, dryG?, dryToWetRatio?
DryingSession      id, batchId, startedAt, endedAt?, tempC, rh, targetProfile
CureCheck          id, containerId, at, rh, burpedAt?, notes
Batch              id, name, createdAt, harvestIds[], labResultIds[]
Container          id, batchId, type, sealedAt, humidityLog[], lastCheckedAt
LabResult          id, batchId, sourceFileRef?, analytes[], flaggedAnalytes[],
                   userConfirmed, reportDate
CycleArchive       id, name, completedAt, plantIds[]
Equipment          id, roomId?, name, maintenanceIntervalDays, lastServiceAt
Expense            id, growId, category, amount, date, equipmentId?, receiptRef?
FlowerStart        id, plantId, flippedAt, observedTrichomeMix?, microscopePhotoIds[]
CalibrationLog     id, meterType, at, bufferValues, result

PERSONAL JOURNAL STORE (separate key, local only)
PersonalEntry      id, at, text, optionalTags[]
  - never referenced by IDs from cultivation records

COMPLIANCE (derived and logged on-device)
ComplianceSnapshot id, at, jurisdictionCode, rulePackVersion,
                   plantCount, canopyTotal, possessionEstimate, statusByRule[]
ComplianceAlert    id, at, ruleId, severity, acknowledgedAt?

REFERENCE CONTENT (read-only, signed remote packs)
RulePack           version, jurisdictionCode, effectiveDate, verifiedAt,
                   signature, rules[] (predicates, limits, citations, precedence)
ContentPack        version, lessons[], breederProfiles[], strainTemplates[]

SHARING
ShareGrant         id, scopeCategories[], roomIds[], plantIds[], expiresAt,
                   revokedAt?, recipientKeyId, rotatedAt
AccessLog          id, grantId, at, action
```

### 5.2 What is implemented today

The shipped store uses SwiftData with these models:

| Model | Closest target entity | Notes |
| --- | --- | --- |
| `GrowProfile` | Grow | Single profile; no name or status. |
| `Room` | Room | Includes light schedule minutes, feed targets and reminder relationships. |
| `Plant` | Plant | Wet and dry weight, disposition, rating and tasting notes live here rather than in a separate harvest entity. |
| `StageEvent` | StageEvent | Stage, date, note and a backfilled flag. |
| `Strain` | Strain | Breeder is free text; observed flowering time is derived from stage events. |
| `JournalEntry` | JournalEntry / Photo | One plant and one room per entry; one photo file plus a thumbnail. |
| `EnvironmentReading` | Reading | Temperature, humidity and light; hourly averages replace raw rows after 30 days. |
| `FeedEvent` | FeedEvent | Room-level feed and watering with pH and EC in and out. |
| `CalibrationEvent` | CalibrationLog | Meter, reading and next due date. |
| `CareReminder` | — | Watering, feeding, reading and calibration prompts. |
| `LightScheduleEvent` | — | Every manual schedule change with the flowering-plant flag. |
| `DryingSession` | DryingSession | Per plant, with target bands, burping mode and checks. |
| `DryingCheck`, `CureBurp` | CureCheck | Daily reading and burp records. |
| `TrainingSession` | TrainingEvent | Date, method, nodes and note on a plant. |
| `Treatment` | Treatment | Product, dose, date, withdrawal and note for plant or room. |
| `Equipment`, `ServiceRecord` | Equipment | Room assignment, service interval and service history. |
| `ScoutingCheck` | ScoutingCheck | Plant or room findings, date, note and optional protected photo. |
| `CycleArchive` | CycleArchive | Named completed cycle; nullifying relationship preserves every plant record. |
| `ComplianceSnapshot` | ComplianceSnapshot | Append-only calculation record: jurisdiction, pack version, stage buckets, retained weight, canopy, limits, warning threshold and per-metric result. No plant or room names. |
| `RuleEvaluationEvent` | RuleEvaluationEvent | One re-check of a saved snapshot under a different pack, with changed fields, citations, per-metric outcomes and an acknowledgment timestamp. |
| `GrowGoal` | — | The grower's own optional cycle targets: a dry yield in grams, a flowering time in weeks and a logging-completeness share. One record; saving with every target off deletes it. |

### 5.3 Design decisions

- **No transfer or sale fields exist anywhere.** Status values are limited to
  active, consumed at home, destroyed, and retained.
- **Rule evaluation is reproducible.** Each compliance snapshot stores the
  rule-pack version, so the app can explain a past status even after the rules
  change.
- **The personal journal has no foreign keys into cultivation data,** so a
  cultivation export cannot accidentally include it.

### 5.4 Migration notes

- The cultivation store now has an explicit versioned schema.
  `CultivationSchemaV1` freezes the model set that shipped with the unversioned
  store; `CultivationSchemaV2` adds only `ComplianceSnapshot` and
  `RuleEvaluationEvent`, and `CultivationMigrationPlan` applies one lightweight
  additive stage. No existing model, relationship, identifier, photo or value is
  rewritten, and a store that cannot be opened still enters recovery rather than
  an empty grow.
- New Tier 3 entities are additive: a threshold, an access log and any future
  stored breeder profile. Each new relationship is optional so a lightweight
  migration keeps existing stores readable.
- The breeder reference itself ships as bundled value types
  (`Models/BreederProfile.swift`), so it adds no model, no export section and no
  migration stage. A grower-editable breeder record would be the additive entity.
- `CultivationSchemaV3` adds only `GrowGoal`, the grower's own optional cycle
  targets, as a second lightweight additive stage after V2. No existing record,
  relationship, identifier, photo or value is rewritten, and a failed save never
  leaves a half-written goal behind.
- `CultivationSchemaV4` adds no model. It records the light-distance fields
  added to `Room` — the stage at the reading and the grower's own target — as a
  third lightweight additive stage. Both are optional, so an existing store
  opens unchanged and a room with no target keeps the app's cited band.
- The personal effect journal lives in its own store with its own key and never
  shares identifiers with the cultivation store.
- Sync is only enabled after a versioned schema migration plan and a conflict
  policy for every entity type are in place.

---

## 6. MVP screen map

### 6.1 Baseline MVP map

```text
ONBOARDING (first launch)
├── Welcome and purpose statement
├── Age confirmation (self-attestation)
├── Federal notice and "verify your local law" disclosure
├── Jurisdiction selection (manual, or approximate location on-device)
│   └── Ineligible jurisdiction → education-only mode notice
├── Residence type and rental or HOA flag
├── Experience level (sets default prompts and detail density)
├── First room (name, indoor or outdoor, canopy area, light type)
└── Rule summary with verification date → Finish

TAB 1: HOME
├── Today card (next tasks, active alerts)
├── Room status cards (temperature, humidity, next feed)
├── Compliance status ring (plant count, canopy, possession)
└── Quick log sheet (watering, feed, reading, photo, note)

TAB 2: PLANTS
├── Plant list (filter by room and stage)
├── Plant detail
│   ├── Stage timeline
│   ├── Feeds and watering history
│   ├── Journal entries and photos
│   └── Stage change sheet
└── Add plant (source, strain, room, count preview against limit)

TAB 3: JOURNAL
├── Entry feed (filter by room, plant, or type)
├── New entry (text, photo, observation chips, link to plant or room)
└── Photo detail (metadata, linked records)

TAB 4: ENVIRONMENT AND TASKS
├── Room list → room detail
│   ├── Readings chart (manual entries in MVP)
│   ├── Light schedule and next on or off time
│   ├── Thresholds (create or edit)
│   └── Reading entry sheet
└── Tasks (scheduled watering, feeding, checks, reminders)

TAB 5: HARVEST AND CURE
├── Harvest list
├── Harvest detail (wet and dry weight, ratio, notes)
├── Drying session (targets, daily check, start and end)
└── Curing checks (container, humidity, burp reminder schedule)

COMPLIANCE (reachable from Home ring and Settings)
├── My rules (plain-language summary, citation, verification date)
├── Rule detail (full text, effective date, change history)
├── Counting breakdown (what counts toward each limit)
└── Alerts history

SETTINGS
├── Jurisdiction and rule-pack status
├── Units and language
├── Notifications (quiet hours, priority, Focus)
├── Security (app lock, grace period, privacy screen)
├── Data (export, backup, delete all)
├── Accessibility preferences
├── Legal (terms, privacy policy, disclaimers, federal notice)
└── About (version, rule-pack version, content updated)
```

The MVP deliberately excluded multi-room management, sensor pairing, widgets,
Watch and Siri from the navigation. The shipped app added multi-room support as
a home and room surface rather than a new tab.

### 6.2 Shipped navigation

```text
ONBOARDING (first launch, and after delete-all)
Apps locks over everything when app lock is on

TAB 1: HOME
├── Compliance ring → breakdown sheet
├── Compliance history and an unacknowledged rule-change review
├── Today (reminders, overdue stages, missing weights, dispositions)
├── Room filter
├── Plants → plant detail → strain library entry
├── Rooms → room detail (environment, feeding, calibration, reminders,
│            light schedule, canopy distance and its target, scouting,
│            treatments and override log)
├── Weekly recap (with this cycle's goals), room comparison, cycle archive,
│   harvest calendar and grow calendar shortcuts
├── Quick Log (water/feed, reading, note, stage) and the garden timeline
└── Latest journal entries

TAB 2: JOURNAL
├── Day-grouped timeline with room filter
├── Entry detail with linked plant or room, and delete that removes its photo
└── New entry (note, observation, photo; linked to plant, room or grow)

TAB 3: STRAINS
├── Library list with observed flowering time and ratings
├── Breeder reference → profile, claims and the strains that point at it
├── Strain detail (claimed vs observed, ratings, plants, notes)
└── Editor (manual, or from a bundled template)

TAB 4: RULES
├── Jurisdiction summary and "This is my jurisdiction"
├── Rule-change notice with changed limits, citations and acknowledgment
├── Live snapshot (counted plants, stored flower, canopy)
├── Compliance history → saved calculation detail
├── Rule detail (summary, citation, source, verified date, stale badge)
└── Federal notice and verification duty

TAB 5: SETTINGS
├── Grow profile
├── Units and compliance warning
├── Home Screen widget (counts only unless task names are allowed)
├── Privacy and data
│   ├── App lock
│   ├── Notifications (priority, quiet hours, lock-screen text)
│   ├── Sharing (encrypted share files, no server or account)
│   ├── Sync and privacy (no account and no cloud sync)
│   ├── Backup and restore (password-protected local backup)
│   └── Export and delete
├── Reports (performance trends, grow report PDF)
├── Equipment
├── Legal notices
└── About

PLANT DETAIL
├── Strain menu, stage badge, stage guidance and one-tap advance
├── Photo strip and side-by-side compare
├── Flowering clock (observed or breeder figure, week strip, overrun warning)
├── Scouting, training and treatment history
├── Dry, cure and rating sections
├── Yield, notes, stage history and delete
```

### 6.3 Where Tier 3 surfaces land

- **Photo analysis:** an "Analyse" action on a journal photo and on the plant
  photo section, with the suggestion reviewed before it is saved.
- **Light distance:** shipped as a card on the room dashboard beside the light
  schedule, with a measurement sheet, a grower-set target and a re-measure
  prompt that names its reason. See `docs/LIGHT_DISTANCE_GUIDANCE.md`.
- **Breeder and pedigree:** shipped as a reference library behind the strain
  library, with a profile screen per breeder, per-cultivar lineage claims
  labelled as claims, and the grower's observed timing beside the claim. See
  `docs/BREEDER_REFERENCE.md`.
- **Sharing:** a Settings section, "Sharing", with the device share code, a scoped
  creator and a reader for received files. Delivery is out of band through the
  system share sheet; there is no server, and a received copy is read-only.
- **Community:** a new tab once moderation and the account model exist; it
  cannot ship inside the current account-free build.
- **Personal effect journal:** a Settings entry, off by default, opening into a
  separately authenticated store.
- **Sync:** a Settings row showing state, the recovery key and the last sync,
  plus an onboarding step when the grower first enables it. Not available today;
  the current screen states that there is no account and no cloud sync. The
  protocol and its cryptographic foundation are recorded in
  `docs/E2EE_DESIGN.md`.
- **Educational library:** a Settings row and contextual "Learn why" links from
  rule and care cards.

---

## 7. Next user-facing releases (v2.1–v2.3)

These are new grower-facing features, chosen so they need no account, no server
and no change to the compliance engine. Every one runs offline, respects app lock,
and is covered by the data inventory: a feature that adds a stored type must add
it to `Services/DataInventory.swift` and to the export/delete coverage test in the
same release.

These features are bound by the product constraints in the review register in
section 1.1, which the completed legal review set: no sale, gift, transfer,
transport or distribution pathway; no health, diagnosis or treatment claims; no
analytics; no third-party SDK; nothing described as available until it is.

### 7.1 One garden timeline

**Problem.** The record is already rich, but it is split across tabs. A grower
who wants "what happened in this room last week" has to visit the journal, the
room, the plant and the harvest screens.

**What ships.** A chronological Garden view that merges, read-only: stage
changes, journal entries, feed and watering events, environment readings,
calibrations, light-schedule changes, training, treatments, scouting checks,
drying checks and burps. Day-grouped, with filters for room, plant and event
type, and a tap that opens the source record.

**Shipped:** `Services/GardenTimeline.swift` merges all twelve record types —
including environment alerts — as one pure, date-ordered list with room and plant attached; the view reads them
through live queries, filters with local state only, and links each row to its
journal entry, plant or room. See `docs/GARDEN_TIMELINE_AND_QUICK_LOG.md`.

**Acceptance criteria.**

- Every stored event type that carries a timestamp appears exactly once, in date
  order, with the room and plant it belongs to.
- Filters are local state and never write to the store.
- A record created or edited elsewhere appears after returning to the view.
- VoiceOver reads each row as type, date, room and a short label; no colour-only
  distinction.
- No new model and no schema change.

**Not in scope.** No inference, scoring, comparison between growers, or
suggested action. The timeline is a reading surface.

### 7.2 Quick Log from Home

**Problem.** Logging a routine watering or reading takes too many taps, which is
the main reason logs go incomplete.

**What ships.** A Quick Log button on Home that opens one sheet with the four
most common actions (water/feed, environment reading, journal note, stage
change), remembers the last room and plant, pre-fills the last values as
editable defaults, and confirms in one step.

**Shipped:** `Views/QuickLog/QuickLogSheet.swift` and `Services/QuickLog.swift`
implement the sheet, prefill, remembered room/plant and the single confirmed
write. A stage change shows the counted total after the change, and a change
that would cross the jurisdiction's plant limit is blocked with the counting
method and citation; the plant detail one-tap advance runs the same check. See
`docs/GARDEN_TIMELINE_AND_QUICK_LOG.md`.

**Acceptance criteria.**

- Four taps or fewer from Home to a saved watering on a grower's second use.
- Nothing is saved until the confirm action; a cancelled sheet writes nothing.
- Pre-filled values are visibly editable and never presented as measured.
- The plant-count pre-save preview still runs before a stage change that would
  cross a limit.

### 7.3 Photo timeline and side-by-side comparison

**Problem.** Growth is visible in photos but the journal shows one image at a
time, so change over a cycle is hard to see.

**What ships.** A per-plant and per-room photo strip in date order, and a compare
mode that puts two selected photos side by side with their dates and stages
labelled. Photos stay in the existing protected store, re-encoded without
location metadata.

**Shipped:** `Services/PhotoTimeline.swift` orders photo entries and resolves the
plant's stage at each photo's date; plant and room detail show the strip and a
compare screen. A journal entry can now be opened and deleted from the journal,
and its display file, thumbnail and cache entry go with it. See
`docs/PHOTO_TIMELINE_AND_GROW_REPORT.md`.

**Acceptance criteria.**

- The compare view labels both dates and both stages, and says when a photo has
  no linked date.
- Deleting a journal entry removes its photo, thumbnail and cache entry, and the
  timeline no longer shows it.
- No image analysis, diagnosis or treatment suggestion is implied or produced.

### 7.4 Local grow report (PDF)

**Problem.** Growers keep records for themselves and sometimes want a printable
summary of a cycle. Today the only external copy is a data archive.

**What ships.** A "Grow report" action that renders a cycle summary to PDF in the
app: stage timeline, feed and reading summary, training, treatments and
scouting, harvest weights and disposition, and the compliance estimate with its
verification duty and rule-pack version. Saved through the system share sheet.

**Shipped:** Settings → Reports opens `GrowReportView`. The report is built from
existing records only, names the rule pack and its verification duty, limits
dispositions to retained, consumed at home and destroyed, excludes the
cultivation journal unless the grower turns it on, and writes a neutral
`Grow-Report-<date>.pdf` through the share sheet. See
`docs/PHOTO_TIMELINE_AND_GROW_REPORT.md`.

**Acceptance criteria.**

- The report states the rule-pack version, the rules-last-updated date and the
  verification duty on the compliance page.
- Disposition is described only as consumed at home, destroyed or retained.
- The report never includes a personal journal entry unless the grower includes
  it explicitly.
- The same non-identifying filename rule as export applies, and the confirmation
  says copies are outside the app.

### 7.5 Widgets with privacy-safe defaults

**Problem.** Checking the day's care tasks means opening the app, which is
friction for a glanceable task list.

**What ships.** A Home Screen and Lock Screen widget showing either generic
counts ("3 care tasks today") or, only when the grower turns it on, task titles.
Defaults are generic. Widget content never shows harvest weights, compliance
numbers or journal text.

**Shipped:** `Grow CompanionWidgetExtension/` adds a WidgetKit extension on the
app group `group.com.organizationName.Grow-Companion.shared`, for the systemSmall
and accessoryRectangular families. `Services/WidgetSnapshot.swift` writes the
shared snapshot whenever a reminder's date, title or state changes: counts always,
task names only when **Settings → Home Screen widget → Show task names** is on,
which is off by default. Tapping the widget opens `growcompanion://today` on Home,
behind whatever lock or cover is showing. Delete-all clears the snapshot and the
preference. See `docs/V2_3_CALENDAR_GOALS_WIDGETS.md`.

**Acceptance criteria.**

- With app lock on and the detail setting off, no plant, room, product or metric
  name appears in any widget state, including the Lock Screen.
- Tapping a widget opens the matching task in the app behind the lock.
- Timeline refreshes are local; no network and no analytics.
- The widget target is added with the project tools, not by editing the project
  file by hand.

### 7.6 Grow calendar with explicit rescheduling

**Problem.** Reminders and stage and harvest windows are spread across screens,
so conflicts are easy to miss.

**What ships.** A month calendar combining reminders, stage windows, harvest
forecast windows and drying or curing check dates. A reminder can be moved to
another day after an explicit confirmation that names the old and new date.

**Shipped:** `Services/GrowCalendar.swift` merges enabled reminders, per-plant
stage windows, harvest forecast windows and the next drying check or curing burp
into one date-ordered list, each entry once. `GrowCalendarService.reschedule`
writes one new due date, keeping the time of day, then cancels the old
notification and schedules exactly one new one; a failed save leaves both
untouched and a past day is rejected. `Views/Home/GrowCalendarView.swift` shows
the month grid, the selected day's type-labelled entries, a move sheet with a
second confirmation naming both dates, and a missed-task card that stays until
the reminder is completed. Reachable from Home. See
`docs/V2_3_CALENDAR_GOALS_WIDGETS.md`.

**Acceptance criteria.**

- Moving a reminder writes one new due date and re-schedules exactly one
  notification; the old request is cancelled.
- Overlapping tasks are visible without relying on colour.
- A missed task stays visible until it is completed or explicitly dismissed.

### 7.7 Per-cycle grow goals

**Problem.** The reports show history but there is no way to say what this cycle
is aiming for.

**What ships.** Optional local targets per cycle: a dry-yield target, a
flowering-week target and a logging-completeness target, with progress shown on
the weekly recap. Targets are the grower's own; there is no cross-grower
comparison, ranking or score.

**Shipped:** `Models/GrowGoal.swift` (schema V3, one additive lightweight stage)
holds the three optional targets; `Services/GrowGoals.swift` measures them from
existing records and reports a figure with nothing to measure as missing rather
than as zero. `Views/Home/GrowGoalsSection.swift` is shown on the weekly recap and
edits or removes the targets. The new model is in the data inventory, export,
backup, restore and delete-all with tests. See
`docs/V2_3_CALENDAR_GOALS_WIDGETS.md`.

**Acceptance criteria.**

- Targets are editable and removable, and appear in export, backup and delete.
- Progress is stated as a value against the grower's target, never as a grade.
- Missing data is shown as missing, not as zero progress.
- Adding the stored type extends the data inventory, the coverage test and the
  delete-all verification before the feature ships.

### 7.8 Spanish localisation and accessible charts

**Problem.** The app is English-only, and several charts have no text
equivalent.

**What ships.** A full Spanish (Mexico) localization of interface copy, units,
dates and plural counts, and a data-table alternative for every chart and ring.

**Status: shipped as a draft for review.** The engineering half is in the app:
numbers, weights, areas, temperatures, volumes, percentages and dates come from
the device locale's formatters, and every chart and the compliance ring has a
text table equivalent reachable with VoiceOver. The Spanish copy is a complete
draft: 1,300 strings cover every user-facing screen, the shared vocabulary, the
chrome and the service-level error copy, including the 148 strings the app
formats with a count, a name or a date. Their keys are the compiled format
patterns (`"%lld plants"`), read from the build rather than guessed, and 23 of
them carry `one`/`other` plural variations that compile into
`es.lproj/Localizable.stringsdict`. Of the 853 keys a build asks for, the 25 that
get no entry are placeholders (`%@ · %@`), separators and unit symbols (`·`,
`–`, `W`, `g`), which read the same in both languages.
`Grow CompanionTests/LocalizationCatalogTests.swift` reads the catalog and fails
if a Spanish value changes a key's placeholders or a plural form is left out.
Model-level, service-level and view-level copy — stage names, the stage-guidance
paragraphs, room types, drying and training vocabulary, notification text, error
messages, the widget's headline and the sentences the views compute — now goes
through `String(localized:)`, so the catalog applies to all of it; the widget
receives its localized line in the shared snapshot because it has its own
bundle. A build asks for 1,218 keys and all but 27 placeholders, unit symbols,
bare numbers and `Grow Companion %@` carry Spanish text. Legal and rule copy
stays in English by design, with an in-app note explaining it: there is exactly
one reviewed version of the copy that matters, not two. See
`docs/LOCALIZATION.md` for the glossary, the rules and what is left.

**Shipped:** `Services/Format.swift` renders numbers through a locale-aware
`NumberFormatter` (a Spanish device sees `24,5`, an English one `24.5`) and dates
through the locale's medium style (`Nov 7, 2026` / `7 nov 2026`), with the
grower's metric or imperial choice still deciding the unit. `Services/ChartTables.swift`
and `Design/ChartTableView.swift` give the environment chart, the out-of-range
bar chart and the compliance ring a `Data table` / `Values as a table` disclosure
that lists every value the picture draws, each row a VoiceOver element. Day counts
go through `String(localized:)` so a plural variant can be supplied later. The
table builders are pure functions with tests. See
`docs/V2_3_CALENDAR_GOALS_WIDGETS.md`.

**Acceptance criteria.**

- No clipped or truncated string at the largest Dynamic Type size in either
  language.
- Numbers, dates, weights and areas use the locale's formatters.
- Every chart has a text or table equivalent reachable with VoiceOver.
- Legal and rule copy stays English, so there is exactly one reviewed version of
  it; the app says so where the copy appears.

### 7.9 Sequencing and dependencies

| Release | Features | Dependencies |
| --- | --- | --- |
| v2.1 | Garden timeline, Quick Log | None; both read existing records. Shipped. |
| v2.2 | Photo timeline and compare, PDF grow report | Verified export/backup and delete coverage (shipped). Both shipped. |
| v2.3 | Widgets, calendar and per-cycle goals (shipped); locale formatters, chart data tables and the Spanish interface including variable and plural strings (shipped) | Widget extension target and the schema V3 migration are in place. Legal copy stays English by design. |

Nothing in this section adds an account, a server, a sync engine, a sensor
firmware update, photo analysis or any transaction. Sharing is the share file
described below; hardware needs a sensor trust model, and photo analysis needs a
validated model and governance before a single suggestion can ship.

**Sharing track status.** Recipient-scoped, encrypted **share files ship**
(`docs/E2EE_DESIGN.md`, `Services/SecureEnvelope.swift`,
`Services/SharePayload.swift`, `Services/SharePackageService.swift`,
`Views/Sharing/`): a versioned, signed AES-GCM envelope, a device key pair and
share code in the Keychain, and tests for scoping, tampering, addressing, expiry
and versioning. The grower writes the file and sends it; the app has no transport
and claims none. Sync is not part of the product and there is no network layer to
turn on.

---

## 8. Technical risks and mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Rule engine produces wrong limits | Medium | Critical | Human-reviewed rule pipeline, signed packs, rollback, "unverified" badges, and a kill switch that freezes evaluation to the last verified pack. |
| Counting logic doesn't match a jurisdiction's definition | High | Critical | Counting predicates modeled in the schema, a visible counting breakdown, and a test suite with reference cases per jurisdiction. |
| Remote rule fetch fails or is tampered with | Very low | High | No remote fetch exists. The rule pack is bundled with the app and a new pack arrives with an app update. |
| Data loss on device failure | Medium | High | Encrypted local backup, a verified export, and a recovery path tested before launch. There is no sync copy by design. |
| Sync conflicts between devices | Very low | Low | There is no second device in the product, so there is no conflict to resolve. |
| End-to-end encryption claim is overstated | Low | Medium | The share file is the only encrypted surface and its threat model is documented; the app makes no claim about cloud storage. |
| Sensor integration fragility | High | Medium | A compatibility matrix, manual fallback for every sensor metric, and clear labels for stale readings. |
| Bluetooth pairing and background limits | High | Medium | Foreground sync by default, background refresh when permitted, and a last-seen timestamp on every sensor. |
| Live Activity and widget limits | Medium | Low | Use Live Activities only for short active sessions; use widget timelines for multi-week countdowns. |
| Notification fatigue | High | Medium | Priority tiers, daily digest option, and automatic suppression for repeated acknowledged alerts. |
| Photo storage growth | High | Low | HEIC compression, thumbnail caching, and an archive-originals option. |
| Model misclassification in photo analysis | Medium | Medium | Show model version, require confirmation, and display uncertainty instead of single answers. |
| Schema drift across app versions | Medium | Medium | Versioned schema migrations with tests on sample databases from every prior version. |
| Accessibility regressions in charts | Medium | Medium | Data-table alternative for every chart, tested with VoiceOver in each release. |
| Vendor SDK exposes data | Medium | High | Audit every SDK's data collection, restrict SDK permissions, and review updates before adoption. |

---

## 9. Suggested success metrics

Metrics measure whether growers achieve better outcomes and stay compliant.
They must not reward maximizing plant count or yield at the expense of legal
limits. Every metric is computed on device for the individual grower and stays
there: nothing is aggregated, reported or uploaded.

| Category | Metric | Definition | Target (first 12 months) |
| --- | --- | --- | --- |
| Crop loss | Plant loss rate | Plants lost to disease, pests, or environmental failure, divided by plants started, per cycle. | Decrease of 20 percent from the grower's own baseline in the first two cycles. |
| Crop loss | Early-warning response rate | Share of threshold alerts acknowledged or acted on within 60 minutes. | 80 percent or higher. |
| Harvest consistency | Yield coefficient of variation | Standard deviation of yield per plant divided by the mean, within one cultivar and room. | Decrease over successive cycles for active users. |
| Harvest consistency | Harvest timing variance | Difference between the actual harvest date and the expected window midpoint. | Median within plus or minus 3 days. |
| Quality | Curing completion rate | Share of harvests with a completed curing log through the target curing period. | 75 percent or higher. |
| Efficiency | Yield per watt trend | Change in dry grams per watt-hour across cycles, using measured watts where available. | Positive trend for users who log for three or more cycles. |
| Compliance | Limit-breach prevention | Number of planting or harvest actions blocked or warned by the compliance check, per user per cycle. | Tracked as a count; no target, because the goal is awareness. |
| Compliance | Compliance-related errors | Records later corrected because the counting method was wrong, per 100 active users. | Decrease quarter over quarter. |
| Compliance | Rule freshness | Share of active grows whose rule pack matches the installed app version. | 100 percent; no pack can lag without an app update. |
| Learning | Lesson-to-action rate | Share of users who open an educational lesson and then perform the linked task within 7 days. | 25 percent or higher. |
| Engagement | Day-30 retention | Share of users who log at least one event in days 25 to 30 after onboarding. | 40 percent or higher. |
| Engagement | Logging completeness | Share of active cycles with feed, reading, and stage events logged on at least 80 percent of scheduled days. | 60 percent or higher. |
| Trust | Export and delete usage | Share of users who run an export or delete-all action, and the completion rate for each. | Completion rate of 99 percent or higher for both. |
| Privacy | Revoked share grant | A revoked or expired grant is refused when the next share file is written. | 100 percent; never presented as a live link. |

The **plant loss rate** and **compliance-related errors** metrics are the most
important indicators of product value. The others support them, and they should
be reviewed together rather than optimized one at a time.

---

## 10. Maintaining this document

- Review at every rule-pack release and after every Tier 3 item ships.
- Update section 1 and section 6.2 whenever a shipped screen changes, so the
  plan and the app never contradict each other.
- The acceptance criteria in section 4 are the working checklist for release:
  a story moves from Partial to Shipped only when every bullet is true.
