import Foundation
import Observation

enum AppLoadState: Equatable {
    case notStarted
    case loading
    case ready
    case failed(String)
}

enum RefreshState: Equatable {
    case idle
    case refreshing
}

enum OnboardingError: Error, LocalizedError {
    case missingDisplayName

    var errorDescription: String? {
        "Give this property a name, such as Home."
    }
}

struct ValidatedProperty: Equatable, Sendable {
    let property: Property
    let snapshot: ScheduleSnapshot
}

@MainActor
@Observable
final class AppModel {
    private(set) var loadState: AppLoadState = .notStarted
    private(set) var refreshState: RefreshState = .idle
    private(set) var property: Property?
    private(set) var snapshot: ScheduleSnapshot?
    private(set) var settings = UserSettings()
    private(set) var completionState = CompletionState()
    private(set) var notificationPermission: NotificationPermissionStatus = .notDetermined
    private(set) var calendarPermission: CalendarPermissionStatus = .notDetermined
    private(set) var liveActivityResult: LiveActivityReconciliationResult = .disabled
    private(set) var isLiveActivityPreviewActive = false
    private(set) var standaloneErrorMessage: String?
    private(set) var integrationMessage: String?
    private(set) var propertySyncMessage: String?
    private(set) var isUpdatingSystemFeatures = false

    let activeProviderIdentifier: String
    let activeProviderDisplayName: String

    private let provider: any CollectionProvider
    private let store: any AppDataStoring
    private let propertySyncStore: any PropertySyncing
    private let completionStore: any CompletionStoring
    private let activityScheduleStore: any SharedActivityScheduleStoring
    private let widgetPayloadStore: any WidgetPayloadStoring
    private let widgetTimelineReloader: any WidgetTimelineReloading
    private let notificationService: any NotificationScheduling
    private let liveActivityService: any LiveActivityScheduling
    private let calendarService: any CalendarSyncServicing
    private let now: @Sendable () -> Date
    private var propertyUpdatedAt = Date.distantPast

    init(
        provider: any CollectionProvider,
        store: any AppDataStoring,
        propertySyncStore: any PropertySyncing = NoopPropertySyncStore(),
        completionStore: any CompletionStoring = VolatileCompletionStore(),
        activityScheduleStore: any SharedActivityScheduleStoring = FileSharedActivityScheduleStore(),
        widgetPayloadStore: any WidgetPayloadStoring = FileWidgetPayloadStore(),
        widgetTimelineReloader: any WidgetTimelineReloading = WidgetTimelineReloader(),
        notificationService: any NotificationScheduling = NoopNotificationService(),
        liveActivityService: any LiveActivityScheduling = NoopLiveActivityService(),
        calendarService: any CalendarSyncServicing = NoopCalendarService(),
        now: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.provider = provider
        self.store = store
        self.propertySyncStore = propertySyncStore
        self.completionStore = completionStore
        self.activityScheduleStore = activityScheduleStore
        self.widgetPayloadStore = widgetPayloadStore
        self.widgetTimelineReloader = widgetTimelineReloader
        self.notificationService = notificationService
        self.liveActivityService = liveActivityService
        self.calendarService = calendarService
        self.now = now
        activeProviderIdentifier = provider.identifier
        activeProviderDisplayName = provider.displayName
    }

    var isUsingFixtureProvider: Bool { activeProviderIdentifier == "fixture" }
    var currentLocalDate: LocalDate { LocalDate(date: now()) }

    func isPutOut(_ occurrenceID: String) -> Bool {
        completionState.isPutOut(occurrenceID)
    }

    func load() async {
        guard case .notStarted = loadState else { return }
        loadState = .loading
        do {
            let persisted = try await store.load()
            property = persisted?.property
            snapshot = persisted?.snapshot
            propertyUpdatedAt = persisted?.propertyUpdatedAt ?? .distantPast
            settings = persisted?.settings ?? UserSettings()
            _ = await mergeSyncedProperty()
            if snapshot == nil, let property {
                do {
                    snapshot = try await provider.schedule(for: property)
                    try await persist()
                } catch {
                    standaloneErrorMessage = Self.message(for: error)
                }
            }
            completionState = try await completionStore.load()
            loadState = .ready
            await refreshPermissionStatuses()
            await reconcileSystemFeatures()
            await publishWidgetPayload()
        } catch {
            loadState = .failed(Self.message(for: error))
        }
    }

    func retryLoad() async {
        loadState = .notStarted
        await load()
    }

    func validate(council: CouncilID, uprn: String, displayName: String) async throws -> ValidatedProperty {
        let validatedUPRN = try UPRNValidator.validated(uprn)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDisplayName.isEmpty else { throw OnboardingError.missingDisplayName }

        let candidate = Property(council: council, uprn: validatedUPRN, displayName: trimmedDisplayName)
        let candidateSnapshot = try await provider.schedule(for: candidate)
        guard !candidateSnapshot.occurrences.isEmpty else { throw CollectionProviderError.noCollections }
        return ValidatedProperty(property: candidate, snapshot: candidateSnapshot)
    }

    func save(_ validatedProperty: ValidatedProperty) async throws {
        property = validatedProperty.property
        snapshot = validatedProperty.snapshot
        propertyUpdatedAt = now()
        standaloneErrorMessage = nil
        try await persist()
        await pushPropertyToSync()
        await publishWidgetPayload()
        await reconcileSystemFeatures()
    }

    func syncPropertyFromCloud() async {
        guard loadState == .ready else { return }
        let changed = await mergeSyncedProperty()
        if changed {
            await refresh()
        }
    }

    func refresh() async {
        guard refreshState == .idle, let property else { return }
        refreshState = .refreshing
        standaloneErrorMessage = nil

        do {
            let refreshedSnapshot = try await provider.schedule(for: property)
            snapshot = refreshedSnapshot
            try await persist()
            await publishWidgetPayload()
            await reconcileSystemFeatures()
        } catch {
            let message = Self.message(for: error)
            if let cachedSnapshot = snapshot {
                snapshot = cachedSnapshot.recordingRefreshFailure(at: now(), message: message)
                try? await persist()
                await publishWidgetPayload()
            } else {
                standaloneErrorMessage = message
                await publishWidgetPayload()
            }
        }
        refreshState = .idle
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        isUpdatingSystemFeatures = true
        integrationMessage = nil
        defer { isUpdatingSystemFeatures = false }

        if enabled {
            do {
                let granted = try await notificationService.requestAuthorization(
                    sound: settings.reminders.notificationSoundEnabled
                )
                notificationPermission = await notificationService.permissionStatus()
                guard granted, notificationPermission == .allowed else {
                    settings.reminders.notificationsEnabled = false
                    integrationMessage = "Notifications are off. You can allow them in System Settings."
                    try? await persist()
                    return
                }
            } catch {
                integrationMessage = Self.message(for: error)
                return
            }
        }

        settings.reminders.notificationsEnabled = enabled
        try? await persist()
        await reconcileSystemFeatures()
    }

    func setNotificationTime(_ date: Date) async {
        let components = LocalDate.calendar.dateComponents([.hour, .minute], from: date)
        settings.reminders.notificationHour = components.hour ?? 17
        settings.reminders.notificationMinute = components.minute ?? 45
        try? await persist()
        await reconcileSystemFeatures()
    }

    func setNotificationSoundEnabled(_ enabled: Bool) async {
        settings.reminders.notificationSoundEnabled = enabled
        try? await persist()
        await reconcileSystemFeatures()
    }

    func setLiveActivitiesEnabled(_ enabled: Bool) async {
        settings.reminders.liveActivitiesEnabled = enabled
        try? await persist()
        await reconcileSystemFeatures()
    }

    func setLiveActivityPreviewEnabled(_ enabled: Bool) async {
        isUpdatingSystemFeatures = true
        integrationMessage = nil
        defer { isUpdatingSystemFeatures = false }

        if enabled {
            guard let snapshot,
                  let segment = LiveActivityPlanBuilder.previewSegment(snapshot: snapshot, now: now()) else {
                integrationMessage = "There is no upcoming collection to preview."
                isLiveActivityPreviewActive = false
                return
            }

            do {
                try await liveActivityService.startPreview(segment, now: now())
            } catch {
                integrationMessage = Self.message(for: error)
            }
        } else {
            await liveActivityService.stopPreview()
        }

        isLiveActivityPreviewActive = await liveActivityService.isPreviewActive()
    }

    func markPutOut(_ occurrenceID: String) async {
        completionState.markPutOut(occurrenceID, at: now())
        try? await completionStore.save(completionState)
        await reconcileSystemFeatures()
    }

    func undoPutOut(_ occurrenceID: String) async {
        completionState.undo(occurrenceID, at: now())
        try? await completionStore.save(completionState)
        await reconcileSystemFeatures()
    }

    func requestCalendarAccess() async -> Bool {
        isUpdatingSystemFeatures = true
        integrationMessage = nil
        defer { isUpdatingSystemFeatures = false }
        do {
            let granted = try await calendarService.requestFullAccess()
            calendarPermission = calendarService.permissionStatus()
            if !granted {
                integrationMessage = "Full Calendar access was not granted."
            }
            return granted
        } catch {
            integrationMessage = Self.message(for: error)
            calendarPermission = calendarService.permissionStatus()
            return false
        }
    }

    func selectCalendar(_ calendar: SelectedCalendar) async {
        isUpdatingSystemFeatures = true
        integrationMessage = nil
        defer { isUpdatingSystemFeatures = false }

        settings.calendar.isEnabled = true
        settings.calendar.selectedCalendarIdentifier = calendar.identifier
        settings.calendar.selectedCalendarTitle = calendar.title
        settings.calendar.suppressedOccurrenceIDs = []
        try? await persist()
        await reconcileCalendar()
    }

    func disableCalendarSync(removeFutureEvents: Bool) async {
        isUpdatingSystemFeatures = true
        integrationMessage = nil
        defer { isUpdatingSystemFeatures = false }
        do {
            if removeFutureEvents {
                settings.calendar = try calendarService.removeFutureManagedEvents(
                    from: settings.calendar,
                    currentDate: currentLocalDate,
                    at: now()
                )
            } else {
                settings.calendar.isEnabled = false
            }
            try await persist()
        } catch {
            integrationMessage = Self.message(for: error)
        }
    }

    func calendarStoreChanged() async {
        guard settings.calendar.isEnabled else { return }
        calendarPermission = calendarService.permissionStatus()
        await reconcileCalendar()
    }

    func refreshPermissionStatuses() async {
        notificationPermission = await notificationService.permissionStatus()
        calendarPermission = calendarService.permissionStatus()
        isLiveActivityPreviewActive = await liveActivityService.isPreviewActive()
    }

    func reconcileSystemFeatures() async {
        guard let snapshot else { return }
        integrationMessage = nil
        let currentTime = now()

        do {
            let reminders = ReminderPlanBuilder.reminders(
                snapshot: snapshot,
                settings: settings.reminders,
                completionState: completionState,
                now: currentTime
            )
            try await notificationService.reconcile(reminders)
        } catch {
            integrationMessage = Self.message(for: error)
        }

        do {
            let activitySchedule = LiveActivityPlanBuilder.schedule(
                snapshot: snapshot,
                settings: settings.reminders,
                completionState: completionState,
                now: currentTime
            )
            try await activityScheduleStore.save(activitySchedule)
            liveActivityResult = try await liveActivityService.reconcile(
                schedule: activitySchedule,
                completionState: completionState,
                now: currentTime
            )
            isLiveActivityPreviewActive = await liveActivityService.isPreviewActive()
        } catch {
            integrationMessage = Self.message(for: error)
        }

        if settings.calendar.isEnabled {
            await reconcileCalendar()
        }
    }

    private func reconcileCalendar() async {
        guard settings.calendar.isEnabled, let snapshot else { return }
        calendarPermission = calendarService.permissionStatus()
        guard calendarPermission == .allowed else {
            integrationMessage = "Full Calendar access is needed to keep selected-calendar events synchronized."
            return
        }

        do {
            let plan = try calendarService.preparePlan(
                snapshot: snapshot,
                state: settings.calendar,
                currentDate: currentLocalDate
            )
            settings.calendar = try calendarService.apply(
                plan: plan,
                to: settings.calendar,
                at: now()
            )
            try await persist()
        } catch {
            integrationMessage = Self.message(for: error)
        }
    }

    private func persist() async throws {
        guard let property else { return }
        try await store.save(
            PersistedAppData(
                property: property,
                snapshot: snapshot,
                propertyUpdatedAt: propertyUpdatedAt,
                settings: settings
            )
        )
    }

    private func mergeSyncedProperty() async -> Bool {
        do {
            if let synced = try await propertySyncStore.load(),
               property == nil || synced.updatedAt > propertyUpdatedAt {
                let previousProperty = property
                property = synced.property
                propertyUpdatedAt = synced.updatedAt
                if snapshot?.propertyID != synced.property.id {
                    snapshot = nil
                }
                try? await persist()
                propertySyncMessage = nil
                return previousProperty != synced.property
            }

            if property != nil, propertyUpdatedAt == .distantPast {
                propertyUpdatedAt = now()
                try? await persist()
            }
            await pushPropertyToSync()
            return false
        } catch {
            propertySyncMessage = "iCloud Keychain sync is unavailable; this device is keeping its local property."
            return false
        }
    }

    private func pushPropertyToSync() async {
        guard let property else { return }
        do {
            try await propertySyncStore.save(
                SyncedPropertyRecord(property: property, updatedAt: propertyUpdatedAt)
            )
            propertySyncMessage = nil
        } catch {
            propertySyncMessage = "iCloud Keychain sync is unavailable; this device is keeping its local property."
        }
    }

    private func publishWidgetPayload() async {
        let payload = WidgetSchedulePayloadBuilder.make(
            property: property,
            snapshot: snapshot,
            now: now()
        )

        do {
            let currentPayload = try await widgetPayloadStore.load()
            guard currentPayload != payload else { return }
            try await widgetPayloadStore.save(payload)
            await widgetTimelineReloader.reloadCollectionWidget()
        } catch {
            // A widget is an optional surface. Keep the app's saved schedule and
            // integrations independent if the shared container is unavailable.
        }
    }

#if DEBUG
    func prepareForPreview(
        property: Property?,
        snapshot: ScheduleSnapshot?,
        loadState: AppLoadState = .ready,
        refreshState: RefreshState = .idle,
        settings: UserSettings = UserSettings(),
        completionState: CompletionState = CompletionState(),
        notificationPermission: NotificationPermissionStatus = .notDetermined,
        calendarPermission: CalendarPermissionStatus = .notDetermined,
        liveActivityResult: LiveActivityReconciliationResult = .disabled,
        standaloneErrorMessage: String? = nil,
        integrationMessage: String? = nil,
        propertySyncMessage: String? = nil,
        isLiveActivityPreviewActive: Bool = false
    ) {
        self.property = property
        self.snapshot = snapshot
        self.loadState = loadState
        self.refreshState = refreshState
        self.settings = settings
        self.completionState = completionState
        self.notificationPermission = notificationPermission
        self.calendarPermission = calendarPermission
        self.liveActivityResult = liveActivityResult
        self.standaloneErrorMessage = standaloneErrorMessage
        self.integrationMessage = integrationMessage
        self.propertySyncMessage = propertySyncMessage
        self.isLiveActivityPreviewActive = isLiveActivityPreviewActive
    }
#endif

    nonisolated static func message(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                return "You appear to be offline. Showing the last saved schedule."
            case .timedOut:
                return "The collection service took too long to respond. Showing the last saved schedule."
            default:
                return "The collection service could not be reached. Showing the last saved schedule."
            }
        }
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            return description
        }
        return "Something went wrong. Please try again."
    }
}
