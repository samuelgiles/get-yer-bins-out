import Foundation
import SwiftUI

#if DEBUG
/// Deterministic, synthetic data for Xcode previews only.
///
/// The fixtures deliberately have no council-facing identity, address, or
/// personal data. Every dependency below is in-memory or a no-op, so rendering
/// a preview never touches the network, system permissions, EventKit, or the
/// shared App Group container.
actor PreviewAppDataStore: AppDataStoring {
    private var data: PersistedAppData?

    init(data: PersistedAppData? = nil) {
        self.data = data
    }

    func load() async throws -> PersistedAppData? {
        data
    }

    func save(_ data: PersistedAppData) async throws {
        self.data = data
    }
}

actor PreviewActivityScheduleStore: SharedActivityScheduleStoring {
    private var schedule = SharedActivitySchedule()

    func load() async throws -> SharedActivitySchedule {
        schedule
    }

    func save(_ schedule: SharedActivitySchedule) async throws {
        self.schedule = schedule
    }
}

actor PreviewWidgetPayloadStore: WidgetPayloadStoring {
    private var payload = WidgetSchedulePayload.empty

    func load() async throws -> WidgetSchedulePayload {
        payload
    }

    func save(_ payload: WidgetSchedulePayload) async throws {
        self.payload = payload
    }
}

struct PreviewCollectionProvider: CollectionProvider {
    let identifier = "preview"
    let displayName = "Preview schedule"

    func schedule(for property: Property) async throws -> ScheduleSnapshot {
        PreviewData.freshSnapshot
    }
}

enum PreviewData {
    enum AppState {
        case onboarding
        case launchLoading
        case launchFailure
        case fresh
        case recyclingOnly
        case wheelieBinMixed
        case gardenWaste
        case empty
        case offline
        case refreshErrorWithRetainedData
        case checkingForSchedule
        case configuredSettings
        case unconfiguredSettings
    }

    static let now = Date(timeIntervalSince1970: 1_786_867_200)
    static let staleFetchedAt = Date(timeIntervalSince1970: 1_786_262_400)
    static let syntheticOverlongUPRN = "0000000000000"
    static let property = Property(
        id: fixtureUUID("A11CE000-0000-4000-8000-000000000001"),
        council: .bristolCityCouncil,
        uprn: "preview-uprn-not-sent",
        displayName: "Preview residence"
    )

    static let recyclingContainers = [
        container(id: "preview-black-recycling-box", label: "Black recycling box"),
        container(id: "preview-green-recycling-box", label: "Green recycling box"),
    ]

    static let wheelieBinMixedContainers = [
        container(id: "preview-wheelie-bin", label: "Black wheelie bin"),
        container(id: "preview-green-recycling-box", label: "Green recycling box"),
        container(id: "preview-food-bin", label: "Food waste bin"),
    ]

    static let gardenWasteContainers = [
        container(id: "preview-garden-bin", label: "Garden waste bin"),
    ]

    static let freshSnapshot = snapshot(
        occurrences: [
            occurrence(on: 18, containers: recyclingContainers),
            occurrence(on: 25, containers: wheelieBinMixedContainers),
            occurrence(on: 1, month: 9, containers: gardenWasteContainers),
        ]
    )

    static let recyclingOnlySnapshot = snapshot(
        occurrences: [occurrence(on: 18, containers: recyclingContainers)]
    )

    static let wheelieBinMixedSnapshot = snapshot(
        occurrences: [occurrence(on: 18, containers: wheelieBinMixedContainers)]
    )

    static let gardenWasteSnapshot = snapshot(
        occurrences: [occurrence(on: 18, containers: gardenWasteContainers)]
    )

    static let emptySnapshot = snapshot(occurrences: [])

    static let staleSnapshot = ScheduleSnapshot(
        propertyID: property.id,
        occurrences: freshSnapshot.occurrences,
        providerIdentifier: "preview",
        providerDisplayName: "Preview schedule",
        fetchedAt: staleFetchedAt
    )

    static let offlineSnapshot = staleSnapshot.recordingRefreshFailure(
        at: now,
        message: "You appear to be offline. Showing the last saved schedule."
    )

    static let refreshErrorSnapshot = freshSnapshot.recordingRefreshFailure(
        at: now,
        message: "The collection service is unavailable right now. Showing the last saved schedule."
    )

    static let configuredSettings: UserSettings = {
        var settings = UserSettings()
        settings.reminders.notificationsEnabled = true
        settings.reminders.notificationHour = 18
        settings.reminders.notificationMinute = 15
        settings.reminders.notificationSoundEnabled = false
        settings.reminders.liveActivitiesEnabled = true
        settings.calendar.isEnabled = true
        settings.calendar.selectedCalendarIdentifier = "preview-calendar"
        settings.calendar.selectedCalendarTitle = "Preview calendar"
        settings.calendar.lastReconciledAt = now
        return settings
    }()

    static let validatedProperty = ValidatedProperty(
        property: property,
        snapshot: freshSnapshot
    )

    @MainActor
    static func model(for state: AppState = .fresh) -> AppModel {
        let model = AppModel(
            provider: PreviewCollectionProvider(),
            store: PreviewAppDataStore(),
            propertySyncStore: NoopPropertySyncStore(),
            completionStore: VolatileCompletionStore(),
            activityScheduleStore: PreviewActivityScheduleStore(),
            widgetPayloadStore: PreviewWidgetPayloadStore(),
            widgetTimelineReloader: NoopWidgetTimelineReloader(),
            notificationService: NoopNotificationService(),
            liveActivityService: NoopLiveActivityService(),
            calendarService: NoopCalendarService(),
            now: { now }
        )

        switch state {
        case .onboarding:
            model.prepareForPreview(property: nil, snapshot: nil)
        case .launchLoading:
            model.prepareForPreview(
                property: nil,
                snapshot: nil,
                loadState: .loading
            )
        case .launchFailure:
            model.prepareForPreview(
                property: nil,
                snapshot: nil,
                loadState: .failed("Preview storage is unavailable.")
            )
        case .fresh:
            model.prepareForPreview(property: property, snapshot: freshSnapshot)
        case .recyclingOnly:
            model.prepareForPreview(property: property, snapshot: recyclingOnlySnapshot)
        case .wheelieBinMixed:
            model.prepareForPreview(property: property, snapshot: wheelieBinMixedSnapshot)
        case .gardenWaste:
            model.prepareForPreview(property: property, snapshot: gardenWasteSnapshot)
        case .empty:
            model.prepareForPreview(property: property, snapshot: emptySnapshot)
        case .offline:
            model.prepareForPreview(property: property, snapshot: offlineSnapshot)
        case .refreshErrorWithRetainedData:
            model.prepareForPreview(property: property, snapshot: refreshErrorSnapshot)
        case .checkingForSchedule:
            model.prepareForPreview(
                property: property,
                snapshot: nil,
                refreshState: .refreshing
            )
        case .configuredSettings:
            model.prepareForPreview(
                property: property,
                snapshot: freshSnapshot,
                settings: configuredSettings,
                notificationPermission: .allowed,
                calendarPermission: .allowed,
                liveActivityResult: .scheduled(segmentCount: 2),
                isLiveActivityPreviewActive: true
            )
        case .unconfiguredSettings:
            model.prepareForPreview(property: nil, snapshot: nil)
        }

        return model
    }

    @MainActor
    static func appView<Content: View>(
        _ content: Content,
        state: AppState = .fresh
    ) -> some View {
        content.environment(model(for: state))
    }

    private static func snapshot(occurrences: [CollectionOccurrence]) -> ScheduleSnapshot {
        ScheduleSnapshot(
            propertyID: property.id,
            occurrences: occurrences,
            providerIdentifier: "preview",
            providerDisplayName: "Preview schedule",
            fetchedAt: now
        )
    }

    private static func occurrence(
        on day: Int,
        month: Int = 8,
        containers: [ContainerKind]
    ) -> CollectionOccurrence {
        CollectionOccurrence(
            propertyID: property.id,
            localDate: localDate(year: 2026, month: month, day: day),
            containers: containers
        )
    }

    private static func container(id: String, label: String) -> ContainerKind {
        ContainerKind(sourceID: id, sourceLabel: label)
    }

    private static func fixtureUUID(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Preview UUID must be valid")
        }
        return uuid
    }

    private static func localDate(year: Int, month: Int, day: Int) -> LocalDate {
        do {
            return try LocalDate(year: year, month: month, day: day)
        } catch {
            preconditionFailure("Preview date must be valid")
        }
    }
}
#endif
