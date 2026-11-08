# Privacy architecture

Grow Companion is a local record. This is the whole boundary, and it is fixed:
there is no account, no server and no network request to add, defer or review.

## The boundary

| Surface | Position |
| --- | --- |
| Account, sign-in, device pairing | None. |
| Server, CloudKit, sync | None. A record exists on the device that made it. |
| Network request of the app's own | None. A link to a primary source opens in the browser, outside the app. |
| Location | None. The grower picks a state from the bundled list; the app never asks for permission and never geocodes. |
| Analytics, ads, crash reporting, third-party SDK | None. |
| Sharing | A signed, encrypted file the grower writes and sends themselves. No transport, no live link. |
| Backups and exports | Local files the grower chooses to write. Copies they make afterwards are outside the app. |

The app says this in Settings → Privacy and in the legal copy, and the wording
does not promise a future cloud feature.

## What enforces it

- `Grow CompanionTests/PrivacyBoundaryTests.swift` scans every app source file
  and the Info.plist. It fails if `URLSession`, `CloudKit`, `CKContainer`,
  `CLLocationManager`, `CLGeocoder`, an `import CoreLocation` or an
  `NSLocation…` usage key appears.
- The privacy screen lists the boundary in product terms, including the parts
  that are not coming.
- Onboarding offers no location button and says no permission is requested.
- The share flow is the only path that produces something for another device,
  and the grower hands it over themselves.

## What stays local but is not more private than this

- **Sensors.** Bluetooth pairing is a local radio connection to a sensor the
  grower owns. The app stores the reading, not a credential.
- **Photos.** Re-encoded on import so location metadata does not survive; the
  files sit in the protected store.
- **App lock and the privacy cover.** Device-owner authentication, with the
  system passcode as the fallback.
- **Widget.** A shared file in the app group; counts by default and names only
  when the grower turns them on.

## Consequences accepted

- No multi-device record. A grower moves a record with an export or a backup,
  not a sync.
- No remote rule update. A new pack arrives with an app update.
- No community, no consultant live access and no personal effect journal; the
  first two would need a server, and the third is not built.
- No aggregate metrics. Everything the app measures is measured on the device
  and stays there.
