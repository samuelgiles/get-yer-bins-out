import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isShowingCalendarChooser = false
    @State private var isShowingDisableCalendarConfirmation = false
    @State private var isShowingPropertySetup = false

    var body: some View {
        NavigationStack {
            List {
                propertySection
                collectionDataSection
                remindersSection
                liveActivitySection
                calendarSection

                if let integrationMessage = appModel.integrationMessage {
                    Section {
                        Label(integrationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }

                Section {
                    Link("Check Bristol service updates", destination: BristolOfficialLinks.serviceUpdates)
                } footer: {
                    Text("Collection dates are scheduled dates, not confirmation that a crew completed collection.")
                }
            }
            .navigationTitle("Settings")
            .disabled(appModel.isUpdatingSystemFeatures)
        }
        .sheet(isPresented: $isShowingCalendarChooser) {
            CalendarChooserView(
                initiallySelectedIdentifier: appModel.settings.calendar.selectedCalendarIdentifier
            ) { calendar in
                isShowingCalendarChooser = false
                Task {
                    await appModel.selectCalendar(calendar)
                }
            } onCancel: {
                isShowingCalendarChooser = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $isShowingPropertySetup) {
            OnboardingView(
                initialProperty: appModel.property,
                cancelAction: { isShowingPropertySetup = false },
                didSave: { isShowingPropertySetup = false }
            )
        }
        .confirmationDialog(
            "Turn off calendar sync?",
            isPresented: $isShowingDisableCalendarConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove future Bins Out events", role: .destructive) {
                Task { await appModel.disableCalendarSync(removeFutureEvents: true) }
            }
            Button("Keep events in Calendar") {
                Task { await appModel.disableCalendarSync(removeFutureEvents: false) }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Past events are kept either way. Bins Out only removes future events it previously created or recovered by occurrence ID.")
        }
    }

    @ViewBuilder
    private var propertySection: some View {
        if let property = appModel.property {
            Section("Property") {
                LabeledContent("Name", value: property.displayName)
                LabeledContent("Council", value: property.council.displayName)
                LabeledContent("UPRN", value: property.uprn)
                    .privacySensitive()
                LabeledContent("Property sync", value: "iCloud Keychain")

                Button("Change council or property", systemImage: "house.and.flag") {
                    isShowingPropertySetup = true
                }

                if let propertySyncMessage = appModel.propertySyncMessage {
                    Label(propertySyncMessage, systemImage: "icloud.slash")
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var collectionDataSection: some View {
        Section {
            LabeledContent("Source", value: appModel.snapshot?.providerDisplayName ?? appModel.activeProviderDisplayName)
            if let snapshot = appModel.snapshot {
                LabeledContent(
                    "Last updated",
                    value: snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)
                )
                if let horizon = snapshot.authoritativeThrough {
                    LabeledContent("Dates through", value: horizon.shortDescription)
                }
            }
            if appModel.isUsingFixtureProvider {
                Label("Development sample data", systemImage: "testtube.2")
                    .foregroundStyle(.orange)
            }
            Link("Bristol collection information", destination: BristolOfficialLinks.collectionInformation)
        } header: {
            Text("Collection data")
        } footer: {
            Text("Only the UPRN is sent to Bristol. Your selected property syncs through iCloud Keychain; each device keeps and refreshes its own last-good schedule cache.")
        }
    }

    private var remindersSection: some View {
        Section {
            Toggle(
                "Evening reminder",
                systemImage: "bell.badge",
                isOn: Binding(
                    get: { appModel.settings.reminders.notificationsEnabled },
                    set: { enabled in Task { await appModel.setNotificationsEnabled(enabled) } }
                )
            )

            if appModel.settings.reminders.notificationsEnabled {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { appModel.settings.reminders.notificationTime },
                        set: { date in Task { await appModel.setNotificationTime(date) } }
                    ),
                    displayedComponents: .hourAndMinute
                )
                Toggle(
                    "Sound",
                    isOn: Binding(
                        get: { appModel.settings.reminders.notificationSoundEnabled },
                        set: { enabled in Task { await appModel.setNotificationSoundEnabled(enabled) } }
                    )
                )
            }

            permissionLabel("Notifications", allowed: appModel.notificationPermission == .allowed)
        } header: {
            Text("Reminders")
        } footer: {
            Text("The default 17:45 reminder is separate from the Live Activity’s required 18:00 start alert.")
        }
    }

    private var liveActivitySection: some View {
        Section {
            Toggle(
                "Live Activity",
                systemImage: "platter.filled.top.iphone",
                isOn: Binding(
                    get: { appModel.settings.reminders.liveActivitiesEnabled },
                    set: { enabled in Task { await appModel.setLiveActivitiesEnabled(enabled) } }
                )
            )

            if appModel.settings.reminders.liveActivitiesEnabled {
                Label("18:00 evening before → 09:00 collection day", systemImage: "clock")
                Text(liveActivityStatusText)
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Preview Live Activity",
                systemImage: "play.rectangle.on.rectangle",
                isOn: Binding(
                    get: { appModel.isLiveActivityPreviewActive },
                    set: { enabled in Task { await appModel.setLiveActivityPreviewEnabled(enabled) } }
                )
            )
        } header: {
            Text("Lock Screen")
        } footer: {
            Text("Preview starts immediately with your next saved collection and can be ended here without marking it complete. The scheduled 18:00–09:00 window uses two linked segments to stay within iOS’s eight-hour limit; notifications remain the fallback.")
        }
    }

    private var calendarSection: some View {
        Section {
            if appModel.settings.calendar.isEnabled {
                LabeledContent(
                    "Calendar",
                    value: appModel.settings.calendar.selectedCalendarTitle ?? "Selected calendar"
                )
                .privacySensitive()

                Button("Choose another calendar", systemImage: "calendar.badge.plus") {
                    isShowingCalendarChooser = true
                }

                if let lastReconciledAt = appModel.settings.calendar.lastReconciledAt {
                    LabeledContent(
                        "Last synced",
                        value: lastReconciledAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }

                Button("Turn off calendar sync", role: .destructive) {
                    isShowingDisableCalendarConfirmation = true
                }
            } else {
                Button("Enable calendar sync", systemImage: "calendar.badge.plus") {
                    Task {
                        if await appModel.requestCalendarAccess() {
                            isShowingCalendarChooser = true
                        }
                    }
                }
            }

            permissionLabel("Full Calendar access", allowed: appModel.calendarPermission == .allowed)
        } header: {
            Text("Calendar")
        } footer: {
            Text("Events are individual all-day dates in your selected writable calendar. Bins Out keeps them up to date from Bristol’s returned schedule and never guesses a recurrence. Calendar alerts may duplicate app reminders if you add them separately.")
        }
    }

    private var liveActivityStatusText: String {
        switch appModel.liveActivityResult {
        case .disabled:
            "Not scheduled"
        case .unavailable:
            "Live Activities are unavailable or disabled in System Settings."
        case .noUpcomingCollection:
            "No future activity needs scheduling."
        case .scheduled(let count):
            "\(count) linked segment(s) prepared for the next scheduled collection."
        }
    }

    private func permissionLabel(_ name: String, allowed: Bool) -> some View {
        Label(
            allowed ? "\(name) allowed" : "\(name) not allowed",
            systemImage: allowed ? "checkmark.circle.fill" : "exclamationmark.circle"
        )
        .foregroundStyle(allowed ? .green : .secondary)
    }
}
