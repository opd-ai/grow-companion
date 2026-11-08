# Garden timeline and Quick Log

Status of the v2.1 release (roadmap sections 7.1 and 7.2). Both features read
records that already exist: there is no new model, no schema change and no new
export or delete path. Everything stays on device and nothing is uploaded.

## Garden timeline

**What ships.** A read-only, day-grouped view of everything that happened in
the garden. It merges these timestamped record types, each exactly once:

| Record | Date | Room and plant shown |
| --- | --- | --- |
| Stage event | stage event date | plant and its room |
| Journal entry | created date | plant and room when linked |
| Feed or watering | event date | room |
| Environment reading | reading date | room |
| Calibration | event date | room |
| Light schedule change | change date | room |
| Training session | session date | plant and its room |
| Treatment | treatment date | planted or room link, plus its room |
| Scouting check | check date | plant or room link, plus its room |
| Drying check | check date | the session's plant and its room |
| Curing burp | burp date | the session's plant and its room |

The merge is `GardenTimelineService.events(from:unit:)`, a pure function over
arrays the view gets from live SwiftData queries. Sorting is descending by date
with a stable identifier tie-break. Because the queries are live, a record
created or edited on another screen appears as soon as the timeline is shown
again.

**Filters.** Room chips, a plant menu limited to the selected room, and a
multi-select event-type menu. `GardenTimelineFilter` is a value type evaluated
locally; applying or clearing a filter writes nothing. The empty state explains
that records are intact and offers to clear all filters.

**Rows.** Each row names the event type with an icon and text (never colour
alone), its time, a short label, and room or plant pills. Rows link to the
source record: a journal entry opens `JournalEntryDetailView`, a plant event
opens `PlantDetailView`, and a room event opens `RoomDetailView`. VoiceOver
reads type, title, date and time, room and plant as one element.

**Placement.** Home shows a "Garden timeline" card beside Quick Log.

## Quick Log

**What ships.** One sheet with four actions: water/feed, environment reading,
journal note and stage change. It remembers the last room and plant and fills
in the last values as starting points. Nothing is written until the grower taps
the confirm button; Cancel writes nothing.

**Remembered context.** `QuickLogPreferences` stores the last room and plant by
their user-visible names in `UserDefaults` under `quickLogRoomName` and
`quickLogPlantName`. Both keys are in `SettingsKey.all`, so delete-all clears
them. A renamed record simply falls back to the first available room or plant.

**Prefills.** The last feed in the room supplies kind, volume, pH and EC; the
latest reading supplies temperature, humidity and light. Filled fields are
ordinary editable text fields, and every form says the values come from the
last log and are not new measurements.

**One-step save.** The service performs exactly one insert per action and one
context save:
- water/feed → `FeedEvent` linked to the room;
- reading → `EnvironmentReading` linked to the room, then the existing
  sustained-alert evaluation;
- note → `JournalEntry`, linked to the chosen plant and room;
- stage → `StageEvent`, the plant's stage, and the harvest date when moving to
  harvest.

**Plant-count preview.** Before a stage change the sheet shows the counted
total after the change against the jurisdiction limit, using
`QuickLogService.countPreview`. Counting matches `ComplianceEngine`: cultivable
jurisdictions only, storage and destroyed plants excluded, the rule's counted
stages, and the clone setting. If the change would exceed the limit, the save
button is replaced by an explanation with the rule's counting note and
citation, and states that nothing was saved. The plant detail one-tap advance
uses the same check and shows the same warning instead of changing the stage.

**Placement and taps.** Home shows a prominent Quick Log card. On a second use,
the sheet starts on water/feed with the last room and last volume already
filled, so a saved watering is two taps from Home.

## Data, privacy and scope

- No new model, no schema change, no migration.
- No new export or delete entry: the timeline derives from records the data
  controls already cover, and the two preference keys are cleared by delete-all.
- No network, analytics, photo analysis, inference, score or suggested action.
- The timeline is a reading surface. Quick Log only performs the record the
  grower confirmed.
- Copy keeps the app's compliance boundary: a limit warning shows the citation
  and tells the grower to verify current law.

## Accessibility

- Timeline rows are combined elements with a spoken label of type, title, date,
  time, room and plant; the type is conveyed with icon and text.
- Quick Log action tiles announce their title and subtitle and the selected
  trait. The count preview is one combined element.
- Fields are standard editable controls; labels use the existing Dynamic Type
  styles, and the sheet scrolls at the largest sizes.
- Reduce Motion: no animated transitions are required for either surface.
- Destructive or blocking copy is text, not colour-only.

## Tests

`Grow CompanionTests/GardenTimelineTests.swift`:
- all twelve timestamped types merged exactly once, in descending order;
- unique identifiers and room/plant associations;
- room, plant, type and combined filters, and that filtering writes nothing.

`Grow CompanionTests/QuickLogTests.swift`:
- feed and reading prefills come from the latest record in the room;
- count preview for a clone crossing the limit, a move that lowers the count,
  an unchanged count, and destroyed plants;
- a stage change writes one stage event and sets the harvest date;
- the same-stage change and an empty note are rejected;
- each quick action writes exactly one record and remembers the context.

The app target and test target compile. This environment has no simulator, so
the suite is compiled but not executed here; CI runs it on an iPhone 17
simulator when a build or pull request reaches `main`.

## Known limitations and decisions

- The timeline loads every environment reading. Very long histories may take a
  moment to build on first open; the list itself is lazy.
- Remembering a room or plant by name means a renamed record loses the
  preference rather than following the rename.
- The default Quick Log action is water/feed; the last action is not remembered.
- The timeline covers the record types the roadmap lists. Equipment service
  history and share access logs are not included, and drying sessions appear
  through their checks and burps rather than a separate start row.
- A stage change that crosses the limit is blocked rather than confirmed with an
  override, matching the roadmap's "save button is replaced with an
  explanation" requirement. There is no ignore-limit path.
- The accessibility work follows the app's existing fixed type scale; a full
  Dynamic Type and Spanish localisation pass remains v2.3 work.
