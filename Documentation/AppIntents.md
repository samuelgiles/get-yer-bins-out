# App Intents

Bins Out uses ordinary, app-owned `AppIntent` types for its read-only questions: next
scheduled collection, when to put containers out, refreshing the schedule, and Bristol
glass-bottle sorting. Apple’s current Assistant Schemas describe system-defined domains
rather than council collection schedules or municipal sorting rules, so the app
deliberately does not force either concept into an unrelated schema.

## Where the answers come from

The intents live in the main iOS/iPadOS app target and use iOS 27 execution-target control
to run in the main app process. Because they run there, they answer from the app’s own
persisted property and `ScheduleSnapshot` through `CollectionAnswerService` — the same data
the app’s own screens use. That is what lets an answer name the configured property, list
the real containers, say whether they have already been put out, and report how fresh the
saved schedule is.

Earlier versions read the widget’s `WidgetSchedulePayload` instead. That payload is built
for a WidgetKit extension that must not perform council networking, and it carries no
completion state and no way to refresh, so Siri could confidently read out a schedule that
had expired weeks earlier. WidgetKit and ActivityKit still use it; the intents no longer
need to.

## Refreshing

`CollectionRefreshPolicy` decides whether a question is worth a council request. It
refreshes when there is no snapshot, when no saved date falls on or after today, or when
the snapshot is more than twelve hours old. After a failed attempt it backs off for fifteen
minutes, so an offline device answers from cache instead of retrying on every question —
and a forced refresh does not override that back-off.

A successful refresh persists the new snapshot, republishes the widget payload, and reloads
the widget timeline. A failed one records the attempt on the cached snapshot and keeps
answering from it, so a bad network never discards the last good schedule. The intent path
uses a ten-second `URLSession` timeout rather than the sixty-second default, which is
longer than an intent’s execution budget.

## What the system displays

Each collection question returns three things:

- a `ScheduledCollectionEntity` value, so other Shortcuts actions can chain the date,
  property label, container list, put-out state, and the evening the containers go out;
- `IntentDialog` with full and supporting text and a symbol, for Siri to speak;
- an interactive snippet, through `SnippetIntent` and `ShowsSnippetIntent`.

`NextCollectionSnippetView` shows the property, the collection summary and symbol, the full
`Europe/London` date, a countdown, the container rows, what follows it, and a freshness
footer. Its **Bins out** button runs the same shared `CollectionCompletionCoordinator` as
the Live Activity’s button, and its **Refresh** button runs `RefreshScheduleIntent`; both
then call `NextCollectionSnippetIntent.reload()`. The snippet intent re-resolves its context
on every `perform()`, so a reload always renders current state rather than replaying the
answer Siri first gave.

## Privacy

No UPRN, address, credential, or raw provider response reaches dialog, display
representations, snippet views, entity identifiers, or the widget payload. The property
appears only under the user’s own local label. Entity identifiers are the existing
occurrence IDs — a random property UUID, a local date, and the council’s own container IDs
— so they stay usable for reconciliation across notification, activity, widget, and EventKit
surfaces. The UPRN is used only as a request parameter to the approved Bristol endpoint,
through the single `BristolAPIConfiguration` point the app already uses.

## Shortcuts

App Shortcuts are registered at launch and include the application-name token in every
supplied phrase. The official Bristol glass guidance opens only through its separate,
explicit shortcut, and through the button on the glass snippet; a sorting question answers
directly without unprompted web navigation.

Source: [Apple’s App Intents system experiences guide](https://developer.apple.com/documentation/appintents/adopting-app-intents-to-support-system-experiences) and [Bristol City Council’s black recycling box guide](https://www.bristol.gov.uk/residents/bins-and-recycling/what-goes-in-your-bins-and-boxes/black-recycling-box).
