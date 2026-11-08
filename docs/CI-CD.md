# iOS CI and TestFlight delivery

## What the workflows do

- `.github/workflows/ios-ci.yml` runs for pushes and pull requests targeting `main`. It uses a GitHub-hosted `macos-26` runner, selects Xcode `26.4.1`, resolves Swift packages, then builds and runs the unit and UI test targets on an iPhone 17 simulator. The same `Grow Companion` scheme embeds the `Grow CompanionWidgetExtension` target, so CI compiles the widget with the app. It does not use signing credentials, so pull requests can run without secrets.
- `.github/workflows/testflight.yml` runs for tags named `v*` and can also be started from the Actions tab. It archives and signs the iOS app, exports an IPA, and uploads it to App Store Connect for TestFlight processing.

The pipelines use Xcode's `xcodebuild` and macOS `security` commands for archive, signing, and export. `xcrun altool` (included with Xcode) uploads the IPA using an App Store Connect API key. This avoids adding a signing/upload dependency to the app and does not use an Apple ID password. The distribution keychain, profile copy, certificate, API key file, archive, and exported IPA are temporary runner files; cleanup runs on success and failure.

## One-time Apple setup

1. Enroll in the Apple Developer Program and choose the app's permanent, explicit bundle identifier. Register that identifier under Certificates, Identifiers & Profiles, then create the matching app record in App Store Connect.
2. Create an **Apple Distribution** certificate and export it from Keychain Access as a password-protected `.p12` that includes its private key.
3. Create an **App Store Connect** provisioning profile for the explicit bundle identifier and the same team/certificate. The profile must include the app's required entitlements.
4. In App Store Connect, create an API key with the **App Manager** role. Download its `.p8` private key once and store it securely; Apple does not offer another download of that key.
5. Add the repository secrets and variable below in GitHub: **Settings → Secrets and variables → Actions**. Do not add certificate, profile, API-key, or `.env` files to the repository.
6. Ensure GitHub Actions and macOS hosted runners are enabled for the repository/account. The selected `macos-26` image provides Xcode `26.4.1` and the iOS 26.4 simulator runtime used by CI.

## GitHub Actions configuration

Add these **repository secrets**:

| Name | Expected value | How to obtain it |
|---|---|---|
| `APPLE_TEAM_ID` | The 10-character Apple Developer Team ID. | Apple Developer account → Membership details. |
| `APPLE_DISTRIBUTION_CERTIFICATE_BASE64` | Base64 text of the `.p12` distribution certificate; line breaks are accepted. | Export the Apple Distribution identity, including its private key, from Keychain Access. On macOS, copy `base64 -i AppleDistribution.p12` output into the secret. |
| `APPLE_DISTRIBUTION_CERTIFICATE_PASSWORD` | The password used when exporting that `.p12`. | Set it during export from Keychain Access. |
| `APPLE_PROVISIONING_PROFILE_BASE64` | Base64 text of the App Store `.mobileprovision` file. | Download the matching profile from Apple Developer → Certificates, Identifiers & Profiles. On macOS, copy `base64 -i AppStore.mobileprovision` output into the secret. |
| `APP_STORE_CONNECT_API_KEY_ID` | The key ID shown when creating the App Store Connect API key. | App Store Connect → Users and Access → Integrations → App Store Connect API. |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer UUID shown for the App Store Connect API key. | The same Integrations page. |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | The full contents of the downloaded `.p8` file, including its `BEGIN` and `END` lines. | The one-time `.p8` download from App Store Connect. Store it securely before adding it as a GitHub secret. |

Also add this **repository variable** (it is configuration, not a credential):

| Name | Expected value | How to obtain it |
|---|---|---|
| `IOS_BUNDLE_ID` | The exact explicit bundle identifier registered for the app, for example `com.example.growcompanion`. | Choose/register the identifier in Apple Developer and use the same identifier for the App Store Connect app and provisioning profile. |

The workflow overrides the project's placeholder bundle identifier and version at archive time. Tag `v1.2.3` produces marketing version `1.2.3`; a manual run can provide a version or use the Xcode project's `MARKETING_VERSION`. The GitHub Actions run number is used as the build number.

## Release procedure

1. Add all the Apple secrets and the `IOS_BUNDLE_ID` variable.
2. Push a version tag such as `v1.0.1`, or open **Actions → TestFlight delivery → Run workflow** and optionally enter a marketing version.
3. Check the workflow run. After Apple's processing finishes, the build appears in the app's TestFlight area in App Store Connect.

The CI workflow runs on pull requests without any of these secrets. The TestFlight workflow requires the secrets and a matching Apple team, bundle ID, certificate, profile, and App Store Connect app. An upload to TestFlight does not by itself submit the app for App Store review or release it publicly.
