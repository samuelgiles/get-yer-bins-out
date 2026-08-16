# Bins Out engineering guide

This project targets iOS 27 with the Xcode 27 toolchain. These rules adapt the modern Swift and SwiftUI guidance from [twostraws/SwiftAgents at commit `70132f3d11561f45ccfab8823bb3d26bbe470b2f`](https://github.com/twostraws/SwiftAgents/tree/70132f3d11561f45ccfab8823bb3d26bbe470b2f), reviewed on 2026-08-16. They are project-specific rules, not a copy or a runtime dependency; upstream has no explicit licence.

## Platform and code

- Use current Swift, SwiftUI, Observation, structured concurrency, and strict concurrency checking. Prefer `async`/`await`, `@Observable`, `NavigationStack`, the modern `Tab` API, `FormatStyle`, semantic styles, and standard controls.
- Target iOS 27. Do not add compatibility branches for older systems unless the product requirement changes.
- Prefer Apple frameworks. Add no runtime third-party dependency without a demonstrated need and explicit review.
- Keep views adaptive: no fixed screen bounds or fixed font sizes. Support Dynamic Type, VoiceOver, light/dark mode, increased contrast, reduced transparency, and reduced motion. Color must never be the only container identifier.
- Split substantial models, services, and views into focused files. Keep business and date logic out of views and cover it with unit tests.
- Use Xcode MCP documentation, build, issue, and preview tools when they are available; otherwise use the selected Xcode 27 command-line toolchain and an iOS 27 simulator.

## Architecture and target boundaries

- Views consume domain models and observable app state; they do not decode transport DTOs, perform council requests, or own persistence.
- All council access goes through `CollectionProvider`. Keep Bristol transport DTOs private to the provider and preserve unknown source container names.
- Keep shared value models, schedule normalization, completion logic, and prepared display data free of app-only APIs so they can later be included in both the app and WidgetKit targets.
- WidgetKit and ActivityKit extensions must not perform council networking or assume the app process is running. They render compact state supplied by ActivityKit or the App Group store.
- App Intents must call one idempotent shared service. A future `Bins out` action means the containers have been put out, must be reversible in the app, and must not mean that Bristol completed collection.
- Scheduled Live Activities must respect the eight-hour active limit. Local notifications remain the reliable fallback; background refresh is opportunistic, never an alarm.

## Data, dates, and privacy

- Treat UPRNs as user-entered strings. Preserve leading zeroes, do not pad, and validate non-empty ASCII digits with a maximum length of 12.
- Treat provider dates as date-only values in the `Europe/London` calendar. Never model them as UTC midnights or infer authoritative dates from a generic cadence. Test GMT and BST boundaries.
- Stable occurrence identity must derive from property identity, local date, and normalized container IDs so it remains useful for notification, activity, widget, and EventKit reconciliation.
- Persist the property and last good snapshot atomically. A failed refresh may add failure metadata but must not discard the last successful schedule.
- Storage must accept an injected App Group container URL. Do not enable an App Group entitlement until an extension target needs it; audit `PrivacyInfo.xcprivacy` required-reason declarations when shared defaults or other covered APIs are introduced.
- The local property name is user-controlled and unverified. Send only the UPRN to the approved Bristol endpoint. Never log full UPRNs, addresses, credentials, raw property responses, calendar titles, or event IDs.
- Bristol has authorized the public APIM client credential shipped by its official website. Keep it in exactly one replaceable `BristolAPIConfiguration` point and do not mistake obfuscation for protection: it is extractable from the app. Operational protection belongs at Bristol through endpoint scope, quotas, monitoring, revocation, and rotation.
- Do not print the public client credential in routine logs, diagnostics, analytics, errors, screenshots, or test output. Any future credential that is actually secret must not be committed.
- Link to official Bristol sorting guidance until written reuse permission is recorded. Always describe feed dates as “scheduled collection”; they do not prove completion.

## Permissions and system integrations

- Ask for notification permission only after reminders are enabled, requesting only capabilities in use.
- Ask for EventKit full event access only after the user explicitly enables selected-calendar reconciliation. Store calendar identifiers, verify writable calendars, preview changes, create individual all-day events, and handle revocation/deletion without duplicating events.
- Keep ActivityKit, WidgetKit, App Intents, EventKit, and notification code behind focused services that can be tested without presenting UI.

## Verification

- Every change must build with Xcode 27 for an iPhone simulator. Run focused unit tests for changed core behavior before widening scope.
- Unit tests cover UPRN validation, defensive provider decoding and errors, unknown containers, same-day grouping, stable identity, `Europe/London` DST transitions, persistence, and last-good-cache behavior.
- Add useful SwiftUI previews for fresh, empty, loading/error/offline, and accessibility-size states. Before shipping system features, verify Live Activities, notifications, App Group sharing, and EventKit on physical hardware.
- Do not weaken assertions, swallow decoding failures, or replace authoritative data with guessed recurrence merely to make a test pass.
- Live Bristol integration tests are explicitly opt-in and require a locally supplied authorized UPRN. CI and the default test scheme must remain deterministic and network-independent.
