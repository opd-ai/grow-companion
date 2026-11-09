# Local-only delivery record

This replaces the earlier safe-release plan. That plan was organised around
release approvals, staged exposure and a privacy sign-off. There are none any
more: the product is a local record with no account, no server and no network
request, so there is no cloud surface, identity model or transport for a review
to open or close.

## What ships

Everything the app does is on the device that made the record:

- onboarding with age attestation, a manually chosen state and a residence
  answer, opening with the interface language: English by default, Español
  selectable there and later in Settings;
- compliance rules from the bundled pack, a live count and an immutable local
  history of each calculation;
- rooms, plants, stages, environment readings, feeds, calibrations, reminders,
  light schedules, training, treatments, scouting and equipment;
- the cultivation journal with protected photos, the garden timeline and Quick
  Log;
- harvest, drying, curing and the grow report;
- per-cycle goals, the grow calendar and the widget, all fed from local data;
- a password-protected local backup, a verified export and delete-all;
- encrypted share files the grower writes and sends themselves;
- the breeder reference, light-distance guidance and the education library.

## Privacy boundary

- No account, sign-in or device pairing.
- No server, CloudKit, URL session or remote rule or content download.
- No location permission and no reverse geocoding: the grower picks a state.
- No analytics, advertising, crash reporter or third-party SDK.
- Sharing is a signed, encrypted file for one recipient; the app has no
  transport and makes no live-link claim.

`Grow CompanionTests/PrivacyBoundaryTests.swift` scans the app sources and the
Info.plist and fails if a network, CloudKit or Core Location API appears.
`docs/PRIVACY_ARCHITECTURE.md` states the same boundary in product terms.

## Data safety

- The store uses an explicit versioned schema and lightweight additive migration
  stages, with a recovery screen instead of an empty grow when it cannot open.
- `DataInventory` is the single list export, backup, restore, delete-all and the
  coverage tests read.
- Delete-all throws instead of swallowing failures, verifies the remaining
  counts and never claims completion it did not reach.
- Backup and export are local files the grower chooses to write; copied files,
  device backups and iCloud backups are outside the app and say so.

## Content

Rule and legal copy ships in the app and stays English, so there is exactly one
reviewed version. Spanish covers the interface, the model and service copy and
the variable and plural strings; a translator review and a device pass at the
largest Dynamic Type size remain worth doing.

## Open engineering work

- Migration fixtures from every released build. None are available from this
  repository, so the migration test builds a V1 store locally.
- The iOS 18 deployment-target decision; the project currently targets iOS 26.
- A two-device test of the share file and a device pass of the Siri and
  Shortcuts watering action.
- A rendered check of the widget and the charts at the largest Dynamic Type
  size, in both languages.

None of these blocks shipping the local app: they are checks that make the local
implementation more reliable.
