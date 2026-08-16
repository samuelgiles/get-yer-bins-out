# Bins Out — Privacy

**Effective and last updated: 16 August 2026**

Bins Out is an independent app. It is **not** made, endorsed, or operated by Bristol
City Council or Bristol Waste Company. It reads Bristol's public collection-date
service on your behalf; it has no other relationship with them.

There is no Bins Out server. There is no account system, no analytics SDK, no
advertising SDK, no tracking, no postcode lookup, and no location access. Nothing
about you is sent to the developer, ever.

## Who is responsible

Bins Out is published by **Samuel Giles**, an individual developer in the United
Kingdom, acting as the data controller for the purposes of UK GDPR and the Data
Protection Act 2018.

Privacy enquiries: **sam@samuelgil.es**

## What Bins Out stores on your device

Everything below is written into the app's shared App Group container on your
device, with iOS file protection set to *complete until first user
authentication*:

- **Your property** — the council you chose, the UPRN you typed, a display label
  you chose yourself, and a random identifier generated on your device.
- **The saved schedule** — the collection dates and container names Bristol
  returned, when they were fetched, and whether the last refresh failed.
- **Your settings** — whether reminders and Live Activities are on, your reminder
  time, and which calendar you selected for sync.
- **Which collections you have marked as done**, so the app and the widget agree.
- **A reduced payload for the widget, Siri and Live Activities** (see below).

The display label is whatever you type. Bins Out never looks up, derives, or
verifies an address, and it does not know your address unless you choose to type
one into that label.

## What is sent to Bristol, and why

When you set up a property and whenever the schedule is refreshed, Bins Out makes
one HTTPS request to Bristol City Council's `NextCollectionDates` endpoint.

**The only thing sent about you is the UPRN you entered.** No name, no label, no
device identifier, no account, no advertising identifier, no location. The request
also carries a public client key that Bristol issues for this endpoint; that key
identifies the app, not you.

This is necessary to answer the question the app exists to answer — Bristol cannot
return your collection dates without knowing which property you mean.

Bristol City Council is the controller of whatever it records at its end,
including any server logs. Their handling of that request is governed by their own
privacy notice, not this one.

## What syncs through iCloud Keychain

Your **selected property record** — council, UPRN, display label, and the random
identifier — is stored as a synchronizable iCloud Keychain item so the same
property appears on your other devices.

This uses Apple's iCloud Keychain, which Apple operates and end-to-end encrypts.
The developer cannot read it, cannot list it, and has no access of any kind to it.
Your saved schedule, settings, and completion state are **not** synced; they stay
local to each device.

## Widget, Siri and Live Activity data

The widget, the App Intents that answer Siri questions, and Live Activities all
read a deliberately reduced payload from the App Group container. It contains:

- your display label,
- the scheduled dates,
- the container names,
- how fresh the saved schedule is.

It deliberately does **not** contain your UPRN, the Bristol client key, the raw
provider response, or anything from your calendar.

Live Activities are started locally on your device (no push tokens are requested,
and no Live Activity content is ever sent to Apple's push service by this app).
Once running, a Live Activity is a system surface: iOS may display it on your Lock
Screen, in the Dynamic Island, in StandBy, on a paired Apple Watch, in CarPlay, or
on a Mac using iPhone Mirroring. Anyone who can see those screens can see your
display label and what goes out next — so choose a label you are comfortable
having visible on a locked screen.

## Calendar events

Calendar sync is **off by default**. If you turn it on, Bins Out asks for full
Calendar access and then asks you to pick a single writable calendar.

Bins Out then creates all-day events in that calendar, one per collection, through
the end of the schedule Bristol returned. Each event contains a short title (for
example "♻️ Recycling"), a note listing the containers and when the schedule was
last refreshed, and a `binsout://` link containing the app's own random occurrence
identifier. **Events never contain your UPRN, your display label, or your
address.**

Once the events are in your calendar they are your calendar's data. If the
calendar you chose belongs to an account synchronised by Apple, Google, Microsoft
Exchange, or any other provider, those events will be uploaded to and stored by
that provider under their terms, and may be visible to anyone you share that
calendar with. Bins Out has no control over and no visibility into that.

## Notifications

Reminders are **off by default** and are entirely local. If you enable them, iOS
asks for notification permission, and Bins Out schedules a local notification for
the evening before each collection (17:45 by default). The notification names the
containers due. Nothing is sent to a server, and no push tokens are used.

## Links to Bristol websites

Bins Out links out to Bristol City Council, Bristol Waste Company, and the
Find My Address UPRN finder. Opening one of these leaves the app and loads the
page in Safari. Those sites are operated by other organisations and have their own
privacy practices; this policy does not cover them.

## Security

- The request to Bristol uses HTTPS (TLS).
- On-device files are written with iOS file protection (complete until first user
  authentication), so they are encrypted at rest while the device is locked and
  has not been unlocked since boot.
- The property record in the keychain is stored with accessibility "after first
  unlock".
- The app writes no logs. It never logs your UPRN or the Bristol client key.
- The Bristol client key is public client configuration, not a secret. It is
  extractable from any copy of the app. Protecting it is a matter of Bristol-side
  endpoint scope, quotas, monitoring, and rotation.

## Retention and deletion — what actually happens today

This section describes the behaviour as currently implemented. It deliberately
does not promise anything the app does not yet do.

- **There is no in-app "erase all my data" button yet.** This is a known gap and
  is listed as future work in the project README.
- **Deleting the app** removes its App Group container, and with it the saved
  property file, schedule, settings, completion state, and widget payload.
- **The iCloud Keychain property record may outlive the app.** Because it is a
  synchronizable keychain item, it can persist on your other devices signed in to
  the same Apple Account, and it can come back after you reinstall. Bins Out
  provides no way to delete it from within the app. To remove it you would need to
  manage it through your Apple Account's keychain, or sign out of iCloud Keychain.
  Please assume it persists.
- **Changing your property replaces the saved record** rather than keeping a
  history, but it does not retroactively erase anything already written elsewhere.
- **Calendar events can survive.** When you turn calendar sync off, Bins Out asks
  whether to remove its future events. If you choose to keep them, they remain in
  your calendar — and with your calendar provider — indefinitely. Events for dates
  that have already passed are never removed automatically. Events you delete
  yourself are respected and not recreated.
- **Delivered notifications** remain in Notification Centre until you clear them,
  as with any app.
- The developer holds no copy of anything, so there is nothing to request from,
  or delete at, the developer.

## Your rights

Because the developer never receives or stores your data, there is no developer-held
record to access, correct, export, or erase. Your data lives on your device, in
your iCloud Keychain, and — if you enabled calendar sync — with your chosen
calendar provider. Rights over the last two are exercised through Apple and
through that provider.

If you believe Bristol City Council holds data about your requests, that is a
matter for Bristol City Council under their own privacy notice. If you are in the
UK and are unhappy with how personal data has been handled, you can complain to
the Information Commissioner's Office at ico.org.uk.

## Changes to this policy

If this policy changes, the "Effective and last updated" date at the top will
change with it, and the previous versions remain visible in this repository's Git
history.

## Contact

**Samuel Giles** — sam@samuelgil.es
