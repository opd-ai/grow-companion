# Photo timeline, compare and PDF grow report

Status of the v2.2 release (roadmap sections 7.3 and 7.4). Both read existing
records; no model, schema, migration or new export path was added. Everything is
on device, and the only way content leaves is when the grower shares a PDF or an
existing export.

## Photo timeline and compare

**What ships.** A photo strip on plant detail and room detail, oldest first, and
a full photo screen with a side-by-side compare panel.

- `PhotoTimelineService` takes journal entries that carry a photo, sorts them by
  date and resolves the plant's stage at the photo's date from its stage events.
  A photo with no linked plant, or taken before the first recorded stage, reads
  **Stage not recorded**; the UI never guesses a stage.
- The date is the journal entry's creation date. `PlantPhoto.date` is optional
  so a record without a usable date renders **Date not recorded** instead of
  pretending.
- Plant detail uses `plant.journalEntries`; room detail includes entries linked
  directly to the room and entries on plants in that room.
- The compare screen shows two columns with date, stage and linked record.
  Tapping photos fills the first and second slot; selecting a third replaces the
  oldest choice. Selection is view state only.
- Photos stay in `PhotoStore` under complete file protection, re-encoded on
  import with location metadata removed. Nothing analyses an image: there is no
  diagnosis, health claim or treatment suggestion anywhere in this flow.

**Journal deletion.** Journal entries now open a detail screen with a delete
action (the tab's cards are navigation links). `JournalEntryService.delete`
deletes the SwiftData entry, saves, and only then removes the display file,
thumbnail and thumbnail cache. A failed save rolls back and leaves the photo in
place. The garden timeline reads the same live query, so a deleted entry and its
photo disappear from it as well.

## PDF grow report

**What ships.** Settings → Reports → **Grow report (PDF)** builds a local report
and hands it to the system share sheet.

**Content.** `GrowReportService.makeData` produces testable sections:

- **Compliance estimate** — jurisdiction, rule-pack version and rules-last-updated
  date, warning threshold, counted plants, stored flower, canopy, levels, the
  rule's counting method and citation. It always states that this is the app's
  calculation, not legal advice.
- **Stage timeline** — every plant with its current stage and dated stage events,
  including backfilled transitions and notes.
- **Feeding and environment summary** — feed/watering counts, total logged
  volume, pH/EC coverage, reading count, averages, readings outside the room
  target and the last records.
- **Training**, **Treatments** and **Scouting checks** — dated entries with the
  linked plant or room.
- **Harvest** — wet and dry weight, disposition, grams per watt, and an explicit
  statement that only retained, consumed at home and destroyed exist. No sale,
  gift, transfer or distribution state can appear, because none exists.
- **Scope and journal** — states that cultivation journal entries are excluded
  unless chosen, that Grow Companion has no personal effect journal, and repeats
  the no-sale/scope copy.

The cultivation journal is **off by default**. When the grower turns on
**Include cultivation journal entries**, the text and tags are included as plain
lines; photos are never embedded. There is no personal effect journal in this
app, so none can leak into a report.

**Rendering.** `GrowReportRenderer` draws an A4 PDF with `UIGraphicsPDFRenderer`:
a header on each page, section headings and wrapped body text, automatic
pagination, and a footer with page number, "generated on this device" and "not
legal advice". The verification duty closes the report.

**File and sharing.** The filename is `Grow-Report-yyyy-MM-dd-HHmm.pdf` — no
plant, room, strain or grower name. The PDF is written to the app's temporary
directory with complete file protection and shared with `ShareLink`. The screen
says that copies shared or saved leave the app and are not removed by
delete-all.

## Privacy and scope

- No new stored type, so the data inventory, export, backup and delete paths are
  unchanged.
- Photos remain in the protected photo folder; the report embeds no photo.
- No network, analytics, third-party SDK or image analysis.
- The report is the grower's own record: no cross-grower comparison, ranking or
  score.
- Legal copy keeps the verification duty and the disposition boundary.

## Accessibility

- Photo strip buttons announce the date and stage; the compare columns read as
  one element per photo; selected thumbnails expose a selected-number value.
- The report screen uses standard labelled controls; the journal toggle explains
  its default in text, not colour.
- The PDF is a text document, not an image, so VoiceOver and text selection work
  on it in a PDF reader.
- The report's content is conveyed with headings and text rather than colour.

## Tests

`Grow CompanionTests/PhotoTimelineTests.swift`:
- photo entries only, oldest first, with stage at each date;
- a photo before the first stage and a photo with no plant read
  "Stage not recorded";
- deleting an entry removes the record, display file, thumbnail and cache entry.

`Grow CompanionTests/GrowReportTests.swift`:
- all required sections are present;
- the rule-pack version, rules-last-updated date and verification duty are in
  the report;
- dispositions contain retained and destroyed and no sale/transfer language;
- the journal is excluded by default and included only when chosen;
- the PDF has a `%PDF` header, is non-trivial in size and uses a neutral
  filename; the temporary file matches the rendered bytes.

The app target and test target compile. This environment has no simulator, so
the suite is compiled but not executed here; CI runs it on an iPhone 17
simulator when a build or pull request reaches `main`.

## Known limitations and decisions

- "Cycle" is the whole current record: every plant and room. Selecting a single
  archived cycle for the report is not part of this phase.
- The journal toggle covers the cultivation journal. There is no personal effect
  journal model, by design.
- Journal photos are not embedded in the PDF, even when journal text is included.
- The report uses canonical metric/detail formatting through the app's unit
  system for weights and areas; PDF typography uses system fonts rather than the
  app's serif/sans theme.
- The PDF is written to the temporary directory and not cleaned up automatically
  after a share.
- English copy only; Spanish localisation and the full Dynamic Type audit remain
  v2.3 work.
