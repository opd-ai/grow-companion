# v2.3 — grow calendar, cycle goals and the widget

Status of the v2.3 release work in `docs/ROADMAP.md` sections 7.5–7.8. Everything
here runs offline, needs no account, adds no network, analytics or third-party
dependency, and respects app lock. Spanish localisation (7.8) remains open.

## Per-cycle grow goals (7.7)

`Models/GrowGoal.swift` stores three optional targets for the current cycle: dry
yield in grams, flowering time in weeks and logging completeness as a share of
days. There is at most one goal record; saving with every target off deletes it,
so nothing empty reaches export or backup.

`Services/GrowGoals.swift` measures each target against records that already
exist:

- **Dry yield** is every recorded `dryWeightGrams` added up. Nil when no plant
  has one, so a missing figure is never shown as zero.
- **Flowering time** is the average, in weeks, of the plants that finished
  flowering. A plant still in flower has no duration yet and is not counted.
- **Logging completeness** is the share of days, from the first record to today,
  that carry at least one record (stage changes, feeds, readings, calibrations,
  light changes, training, treatments, scouting, drying or curing checks, journal
  entries). Nil when there is no record at all.

Progress is always stated as a value against the grower's own number
(`125 g · target 250 g`), never as a grade, ranking or comparison. A target with
nothing to measure reads `Nothing to measure yet` and draws no bar.

The editor and the recap section are in `Views/Home/GrowGoalsSection.swift`, shown
on the weekly recap (`Views/Home/WeeklyRecapView.swift`). Targets are editable and
removable at any time.

**Schema.** `CultivationSchemaV3` adds only `GrowGoal`; `CultivationMigrationPlan`
runs a second lightweight, additive stage after V2. No existing model,
relationship, identifier, photo or value is rewritten.

**Data controls.** `GrowGoal` is in `DataInventory` (counted, labelled, deleted),
in `ExportService.exportedModelNames`, in the export JSON as `goals` and in the
backup as the `goals` section, whose count a v2 manifest can verify. Restore
reinserts it. `producer` now reports `cultivation-v3` / schema version 3.

## Grow calendar with explicit rescheduling (7.6)

`Services/GrowCalendar.swift` merges, for one month:

- enabled care reminders on their next due date,
- a stage window per active plant (the stage started at plus the stage's typical
  span, labelled as a nudge, not a deadline),
- the harvest forecast window of every flowering plant (from
  `HarvestCalendar.forecast`),
- the next drying check (one day after the last check) or curing burp (the burp
  mode's interval), per active drying session.

Entries are date ordered and identified once each. Nothing is inferred beyond
those dates and nothing is written by the merge.

**Rescheduling.** `GrowCalendarService.reschedule` moves one reminder to another
day, keeping its time of day. The store is written first: a failed save rolls back
and leaves both the due date and the existing notification untouched. On success
the old request is cancelled and exactly one new one is scheduled. The notification
side is behind `ReminderScheduling`, so tests use a spy and assert exactly one
cancel and one schedule. A move to a day that has already passed is rejected.

`Views/Home/GrowCalendarView.swift` shows the month grid, the selected day's
entries, and a move sheet that states the old and new date and asks for a second
confirmation naming both. Overlapping tasks are visible as a count on each day and
as a full, type-labelled list, never by colour alone. Missed tasks stay in a card
at the top until the grower completes them.

Reachable from Home's quick actions.

## Counts-first widget (7.5)

`Grow CompanionWidgetExtension/` is a WidgetKit extension on the app group
`group.com.organizationName.Grow-Companion.shared`, supporting the Home Screen
(systemSmall) and Lock Screen (accessoryRectangular) families.

The app writes a small snapshot (`Services/WidgetSnapshot.swift`) whenever a
reminder's date, title or state changes. The snapshot always carries counts;
task names are included only when the grower turns **Settings → Home Screen
widget → Show task names** on, which is off by default. With the setting off the
widget shows `2 care tasks today` and nothing else — no plant, room, product,
metric, weight, compliance number or journal text in any state.

Tapping the widget opens `growcompanion://today`, which selects Home; the app
lock and privacy cover stay in front of it as usual. Timeline refreshes are
local, every 30 minutes, with no network and no analytics.

Delete-all clears the shared snapshot and the preference with the rest of the
app-owned state.

## Accessibility

- Goals: each row combines into one VoiceOver element reading the target and the
  measured value; the progress bar is hidden from VoiceOver because the text
  already states both numbers.
- Calendar: each day is a button labelled with its date, item count and the kinds
  of item; the selected day carries the selected trait. Every row states its kind
  and title as one element.
- Widget: the system card and the Lock Screen row combine into one element that
  reads the count, the overdue count and any allowed task names.
- Dynamic Type: all copy wraps rather than truncating; the month grid keeps a
  fixed day cell with a count under the date.

## Tests

Compiled but not executed here (this environment has no simulator; CI runs the
suite on an iPhone 17 simulator):

- `Grow CompanionTests/GrowGoalsTests.swift` — missing vs measured dry yield,
  flowering time for finished plants, logging completeness over a window,
  validation, removal, single record, missing-data progress, JSON and backup
  coverage, delete-all, and the schema/migration sanity check.
- `Grow CompanionTests/GrowCalendarTests.swift` — the merge from every source,
  disabled reminders, curing intervals, the single reschedule, rejection of a
  past day, and missed tasks staying listed until completed.
- `Grow CompanionTests/WidgetSnapshotTests.swift` — counts with no names by
  default, names only when allowed, disabled reminders excluded.

## Open

- **Spanish copy (7.8).** The locale plumbing and the chart data tables ship (see
  below); the Spanish text for every screen does not. It needs a translator and
  the legal-translation review recorded in the roadmap, because legal and rule
  copy must stay in English with a note until that review exists.
- The widget is covered by unit tests for its payload; its rendered appearance
  and the widget gallery need a device or simulator check.
- The reminder move re-schedules one notification, which is what the app uses
  today; there is still no recurring notification chain to re-schedule.

## Locale-aware formatting and accessible charts (7.8, engineering half)

**Numbers and dates.** `Services/Format.swift` no longer hard-codes a format
pattern or a decimal point. `Format.number` uses a locale-aware `NumberFormatter`,
so weights, areas, temperatures, volumes and percentages follow the device
language (`1,5 g` in Spanish, `1.5 g` in English). `Format.shortDate` uses the
locale's medium date style (`Nov 7, 2026` / `7 nov 2026`), and `Format.time` the
locale's short time. The grower's metric or imperial choice still decides which
unit is shown and converted; the unit symbols (`g`, `kg`, `oz`, `°C`, `m²`,
`ft²`, `L`, `gal`) are language-neutral. `Format.dayCount` goes through
`String(localized:)`, so a plural variant can be added in a String Catalog without
touching the call sites. Tests set `Format.locale` to `en_US`, `es_ES` and
`es_MX` and assert the separators, conversions and date output.

**Every chart has a table.** `Services/ChartTables.swift` builds the rows and
`Design/ChartTableView.swift` renders a `Data table` (or `Values as a table`)
disclosure under each picture:

- the environment line chart (`ChartTables.environment`), replacing its inline
  list so both charts use the same component;
- the out-of-range bar chart in the performance report
  (`ChartTables.weeklyCounts`);
- the compliance ring in the breakdown sheet (`ChartTables.compliance`), which
  also states each metric's level and flags an over-limit value.

Each row is one VoiceOver element reading `label: value`, and the disclosure's
hint is the same sentence the chart speaks, so a grower who cannot see the shape
hears the values. The builders are pure functions, tested without a screen.

**Translating the app when the copy is approved.** The app already uses
`Text("literal")` and `String(localized:)` throughout, so the work is a String
Catalog plus a `knownRegions` entry for `es-MX`, not a source rewrite. In order:

1. Resolve the copy through a translator, then through the Spanish legal copy's
   own localisation review. The general legal review of the English copy is
   complete (`docs/ROADMAP.md` section 1.1).
2. Add `Localizable.xcstrings` with `en` as the source language and `es-MX`
   translations; leave every legal, rule and verification-duty string in English
   and keep the visible note that says so.
3. Add plural variations for the strings that carry counts
   (`Format.dayCount`, the reminder and plant counts).
4. Check the largest Dynamic Type size in both languages on a device, since no
   layout here can be verified from the build alone.

