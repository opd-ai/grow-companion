# Grow Companion

Grow Companion is a local-first iOS app for keeping cultivation records: rooms and plants, care and environment logs, a journal, harvest and curing records, compliance references, and a Home Screen care widget. Records stay on the device unless the grower explicitly exports or shares a file. The app has no account, server sync, analytics, or location lookup.

## Project structure

- `Grow Companion/` — SwiftUI app, SwiftData models, services, rules, localization catalog, and assets.
- `Grow CompanionWidgetExtension/` — care-count widget extension. Task names are omitted unless the grower enables them.
- `Grow CompanionTests/` — unit and service tests, including data-safety, privacy-boundary, localization, and feature tests.
- `Grow CompanionUITests/` — launch-level UI tests.
- `docs/` — product constraints, architecture and privacy notes, feature references, and CI/release guidance.

## Build and test

The project currently targets iOS 26. Xcode 26.4.1 is selected by the GitHub Actions workflows. Open `Grow Companion.xcodeproj` and use the `Grow Companion` scheme to build the app. The CI workflow runs unit and UI tests on an iPhone 17 simulator:

`xcodebuild test -project "Grow Companion.xcodeproj" -scheme "Grow Companion" -destination "platform=iOS Simulator,name=iPhone 17" -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`

The simulator runtime must be installed for that destination. On this device, the project built successfully with Xcode 27.1, but no iOS simulator runtime was available to run the test suite; use the CI workflow for test execution.

## Data and privacy

Backups and exports are local files the user chooses to create. Password-protected backups use the versioned encrypted envelope; shares are encrypted files transferred out of band. Neither feature provides a server or live-link. Delete-all removes app-owned local records and preferences, not files already saved elsewhere or copies controlled by iOS backups. See [Data safety](docs/DATA_SAFETY.md), [Privacy architecture](docs/PRIVACY_ARCHITECTURE.md), and [Feature plan](docs/FEATURE_PLAN.md).

## Release readiness

The project currently contains placeholder bundle identifiers (`com.organizationName...`) and a placeholder App Group. The TestFlight workflow also applies one bundle identifier and one provisioning profile globally even though the app embeds a separately identified widget extension. Before a release archive, choose and register permanent app and extension identifiers, register the shared App Group, and update the workflow to use target-specific signing and provisioning-profile mappings. The required Apple credentials belong in GitHub Actions secrets, never in the repository; setup is documented in [CI/CD](docs/CI-CD.md).

A successful simulator build is not a release approval. Device checks for file protection, Face ID/passcode behavior, notifications, widget rendering, migrations from released stores, and the App Store privacy and policy review still require human/device/account verification. The app's legal and jurisdiction content also needs the review described in the project documentation.
