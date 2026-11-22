# iOS CI and TestFlight delivery

## Workflows

- `.github/workflows/ios-ci.yml` runs for pushes and pull requests targeting `main`. It selects Xcode `26.4.1` on `macos-26`, resolves packages, and runs the unit and UI tests on an iPhone 17 simulator. It needs no signing credentials.
- `.github/workflows/testflight.yml` runs for `v*` tags or manually from Actions. It validates the configured app, widget, and App Group identifiers, uses Xcode automatic signing and the Team API key for both archive and export, then uploads the IPA with `altool`.

The project uses these identifiers, chosen from the repository owner and not yet confirmed registered or available with Apple:

- App: `com.opdai.growcompanion`
- Widget extension: `com.opdai.growcompanion.growcompanionwidgetextension`
- Shared App Group: `group.com.opdai.growcompanion.shared`

The workflow does not override `PRODUCT_BUNDLE_IDENTIFIER` or pass one provisioning profile to every target. Xcode reads distinct app and widget identifiers from the project and automatically provisions each. It fails before archiving if the repository variables do not match the project settings and both entitlements.

## Apple setup still required

1. Confirm the identifiers above are available for the Apple Developer team, register the app and widget Bundle IDs, and create the App Store Connect app record for the app ID.
2. Register `group.com.opdai.growcompanion.shared` as an App Group and enable it for both Bundle IDs. Confirm the app's time-sensitive-notification entitlement is permitted for the app ID.
3. Use a Team API key with the **Admin** role for CI signing. Creating a Team key requires an App Store Connect Admin account. Apple documents the Admin role as having the Certificates, Identifiers & Profiles access and cloud-managed certificate permissions this workflow needs. An App Manager may be granted those permissions as a user, but Apple does not clarify whether those grants apply to API keys; do not assume an App Manager key can provision. Individual API keys cannot use provisioning endpoints.
4. Keep the API key's `.p8` private key secure. Add the secrets and repository variables below in GitHub under **Settings → Secrets and variables → Actions**. Do not add credentials, profiles, or certificates to the repository.
5. Ensure GitHub Actions billing and macOS runner access are active. Hosted runner capacity, account policy, and billing are external to the repository.

Both archive and export use `-allowProvisioningUpdates` with the Team key's `-authenticationKeyPath`, `-authenticationKeyID`, and `-authenticationKeyIssuerID` arguments so Xcode can manage signing assets on a clean runner. The workflow does not need a manually supplied `.p12` or `.mobileprovision` secret; cloud-managed signing keeps private certificate keys on Apple's servers. The App Group must already be registered and enabled as above; this repository cannot do that on the user's Apple account.

## GitHub Actions configuration

Add these **repository secrets**:

| Name | Expected value | How to obtain it |
|---|---|---|
| `APPLE_TEAM_ID` | The 10-character Apple Developer Team ID. | Apple Developer account → Membership details. |
| `APP_STORE_CONNECT_API_KEY_ID` | The key ID for a Team API key. | App Store Connect → Users and Access → Integrations → App Store Connect API. |
| `APP_STORE_CONNECT_ISSUER_ID` | The issuer UUID for that Team key. | The same Integrations page. |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | The full contents of the downloaded `.p8` file, including its `BEGIN` and `END` lines. | The one-time download for the Team API key. Store it securely before adding it as a secret. |

Add these **repository variables** (not credentials):

| Name | Required value |
|---|---|
| `IOS_BUNDLE_ID` | `com.opdai.growcompanion` |
| `IOS_WIDGET_BUNDLE_ID` | `com.opdai.growcompanion.growcompanionwidgetextension` |
| `IOS_APP_GROUP_ID` | `group.com.opdai.growcompanion.shared` |

The workflow checks these values against the Xcode build settings and both entitlement files. A mismatch fails before signing. If Apple reports that an identifier is unavailable, stop and choose a replacement with the account owner; update it using the Xcode project settings tool and update the matching registrations and GitHub variables. Do not try to work around a mismatch by passing a global bundle-ID override.

## Release procedure

1. Complete the Apple setup and verify the Team API key has signing permissions.
2. Add the four secrets and three variables above.
3. Push a version tag such as `v1.0.1`, or open **Actions → TestFlight delivery → Run workflow** and optionally enter a marketing version. The workflow uses the tag version or the Xcode project version and the GitHub Actions run number as the build number.
4. Confirm automatic signing, archive/export, and the upload step succeeded. Apple processing may take additional time before the build appears in TestFlight.

An upload to TestFlight does not submit the app for App Store review or release it publicly. Device-level privacy, notification, widget, migration, accessibility, localization, and App Store review checks remain necessary before public release.
