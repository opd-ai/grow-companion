# Light-distance guidance

Room → *Measure light distance* opens `Views/Rooms/LightDistanceView.swift`. It
answers one question: is the fixture at a useful distance from the canopy for
the stage this room is in? The room dashboard carries the same reading as a
card, so the answer is visible without opening the sheet.

Everything is on device. No photo, depth frame, reading or target leaves the
phone, and there is no network call.

## What it does

- **Measure or type.** On a device with LiDAR, the sheet reads the centre depth
  sample while the camera points at the canopy. On every device, a typed
  distance is a complete path: the same target, the same verdict, the same
  saved record. Depth frames are read in memory and never stored — only the
  resulting distance is kept, with its method (`LiDAR` or `manual`).
- **Cite the figure.** Each band comes from the fixture type's general
  manufacturer guidance and carries a source line and a review date
  (`LightDistanceService.reviewDate`). The app never presents it as a rule for
  a specific fixture.
- **Stage factor.** Seedlings and clones are read farther from the fixture,
  vegetative plants sit a little above the base band, and a room past flowering
  keeps the flowering band. A room with no plants uses the vegetative band.
- **Grower-set target.** A grower whose fixture sheet differs can set their own
  lower and upper bound. It is stored on the room, labelled as their own, and
  replaces the cited band for every stage — the stage factor is not applied to
  a figure the grower supplied.
- **Re-measure prompt.** The card and the sheet say why a new measurement is
  worth taking: none yet, the room's stage changed since the reading, training
  was recorded after it, or the reading is more than 14 days old. The first
  matching reason wins, in that order.
- **Units.** Metric shows centimetres, imperial inches. A typed value is read in
  the grower's own unit, with a comma accepted as the decimal separator.

## Data

| Field on `Room` | Meaning |
| --- | --- |
| `lightFixtureRaw` | The fixture type whose guidance applies. |
| `canopyDistanceMeters` | The confirmed distance, in metres. |
| `canopyDistanceMeasuredAt` | When it was confirmed. |
| `canopyDistanceSourceRaw` | `lidar` or `manual`. |
| `canopyDistanceStageRaw` | The room's stage when it was confirmed. |
| `lightTargetLowerMeters`, `lightTargetUpperMeters` | The grower's own target, or nil for the cited band. |

`CultivationSchemaV4` adds no model: it records those light-distance fields on
`Room` as one more lightweight additive stage, so the declared schema version
matches the store's shape. All of them are optional, and a room that has never
been measured keeps working. Export and backup carry the new fields; delete-all
already removes rooms.

## Decisions

- **One grower-set range per room, not per stage.** A fixture manual usually
  gives one hang height, so a single range that applies to the room is the
  smaller, clearer control. The app stops applying the stage factor to it and
  says so.
- **Post-flower stages reuse the flowering band.** A room's dominant stage is
  the most advanced plant in it; harvest, cure and storage keep the flowering
  band because that was the last canopy that mattered, and returning "no target"
  would blank the card for a room that still holds flowering plants.
- **A prompt, not a new notification type.** The re-measure advice is a local,
  derived state computed from the room's own records. It adds no stored type, no
  notification category and no background work; the existing reminder editor
  remains the way to schedule a notification.
- **Absurd input is rejected, not clamped.** A typed distance outside 0.02–10 m,
  an inverted bound, or a target below 10 cm is refused with an explanation
  rather than silently moved.

## Tests

`Grow CompanionTests/LightDistanceTests.swift` covers the cited bands and the
seedling and vegetative factors, the finish stages, fixtures with no band,
grower targets over every stage and over a fixture with no band, inverted and
zero targets, status boundaries and the missing-reading case, every re-measure
reason with its ordering, unit parsing and display, and the stored room fields
including the schema version and migration stage count.

## Remaining work

- Per-fixture targets entered by the grower are stored per room, not per fixture
  model; a library of grower fixtures would need its own entity.
- Nothing suggests a distance change from a photo, a training session's nodes
  affected, or a measured light intensity. The feature reads what the grower
  recorded and cites a general band.
