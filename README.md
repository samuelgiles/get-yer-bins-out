# Bins Out

Bins Out is an iOS 27 SwiftUI app for property-specific Bristol bin and recycling collection days.

Normal app launches use `BristolCollectionProvider` and the council-authorized public client configuration. Previews and unit tests inject the deterministic fixture provider, and a developer can launch the app with `BINS_OUT_USE_FIXTURE=1` when intentionally working offline.

The Bristol API credential is public client configuration authorized by Bristol City Council and centralized in `BristolAPIConfiguration`. It is necessarily extractable from the binary. Endpoint scope, quotas, monitoring, revocation, and rotation on Bristol's side—not obfuscation in the app—must provide operational protection. The app does not print the value.

Build and test with the Xcode 27 beta:

```sh
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project BinsOut.xcodeproj -scheme BinsOut \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' build

DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer \
  xcodebuild -project BinsOut.xcodeproj -scheme BinsOut \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' test
```

The live client posts only the exact UPRN string to Bristol City Council's approved `NextCollectionDates` endpoint. No postcode, location, analytics, account, or developer-operated backend is used.

## System features

- Evening reminders are opt-in local notifications, defaulting to 17:45 on the evening before collection. Notification permission is requested only when the toggle is enabled.
- The opt-in Live Activity covers the requested 18:00–09:00 local window with two linked, pre-scheduled segments because iOS limits one standard Live Activity to eight hours. Both segments use the same authenticated `Bins out` intent, App Group completion state, and notification cancellation path. The system requires an alert when each scheduled segment begins.
- Settings includes a transient Live Activity preview toggle. It uses the next saved collection, starts immediately, and has isolated identity so closing it never marks or cancels the real occurrence.
- Calendar sync requests full EventKit access only after opt-in, presents Apple's writable single-calendar chooser, previews individual all-day additions/updates/removals, and reconciles stable occurrence and event identifiers. A Calendar event that the user deletes is suppressed rather than silently recreated.

The app and WidgetKit extension use the `group.com.samuelgiles.BinsOut` App Group. Configure that capability for both bundle identifiers in the signing team before device testing. The unsigned simulator build exercises compilation and pure reconciliation logic, but notification delivery, the overnight Live Activity handoff, locked-device intent authentication, App Group signing, and EventKit UI still require physical-device verification.

The live XCTest is skipped by default. For an authorized local run, supply `BINS_OUT_RUN_LIVE_TESTS=1` and `BINS_OUT_LIVE_TEST_UPRN` through a local test environment; never add a real property identifier or display name to the scheme or repository.
