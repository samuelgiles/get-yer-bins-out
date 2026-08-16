# App Intents

Bins Out uses ordinary, app-owned `AppIntent` types for its three read-only
questions: next scheduled collection, when to put containers out, and Bristol
glass-bottle sorting. Apple’s current Assistant Schemas describe system-defined
domains rather than council collection schedules or municipal sorting rules, so
the app deliberately does not force either concept into an unrelated schema.

The intents live in the main iOS/iPadOS app target, use iOS 27 execution-target
control to run in the main app, and have no provider/network dependency. They
read `WidgetSchedulePayload` from the App Group, the same privacy-minimised
handoff used by the widget. It has a local property label, scheduled local dates,
container labels, freshness state, and no UPRN, credential, raw response, or
EventKit information.

The App Shortcuts are registered at launch and include the application-name token
in every supplied phrase. The official Bristol glass guidance opens only through
its separate, explicit shortcut; a sorting question answers directly without
unprompted web navigation.

Source: [Apple’s App Intents system experiences guide](https://developer.apple.com/documentation/appintents/adopting-app-intents-to-support-system-experiences) and [Bristol City Council’s black recycling box guide](https://www.bristol.gov.uk/residents/bins-and-recycling/what-goes-in-your-bins-and-boxes/black-recycling-box).
