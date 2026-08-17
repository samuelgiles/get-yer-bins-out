import Foundation

/// Resolves the configured property's schedule for App Intents, snippets, and entities.
/// Runs in the app process, so it reads the app's own persisted property and snapshot
/// rather than the widget's cut-down payload.
struct CollectionAnswerService: Sendable {
    private let store: any AppDataStoring
    private let completionStore: any CompletionStoring
    private let provider: any CollectionProvider
    private let widgetPayloadStore: any WidgetPayloadStoring
    private let widgetTimelineReloader: any WidgetTimelineReloading
    private let policy: CollectionRefreshPolicy
    private let now: @Sendable () -> Date

    init(
        store: any AppDataStoring = FileAppDataStore(),
        completionStore: any CompletionStoring = FileCompletionStore(),
        provider: any CollectionProvider = AppEnvironment.intentProvider,
        widgetPayloadStore: any WidgetPayloadStoring = FileWidgetPayloadStore(),
        widgetTimelineReloader: any WidgetTimelineReloading = WidgetTimelineReloader(),
        policy: CollectionRefreshPolicy = .default,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.store = store
        self.completionStore = completionStore
        self.provider = provider
        self.widgetPayloadStore = widgetPayloadStore
        self.widgetTimelineReloader = widgetTimelineReloader
        self.policy = policy
        self.now = now
    }

    func context(refresh mode: CollectionRefreshMode = .ifStale) async -> CollectionAnswerContext {
        let currentTime = now()
        let today = LocalDate(date: currentTime)

        // `try?` would flatten "nothing saved yet" and "could not be read" into one `nil`,
        // and those want different answers.
        let loaded: PersistedAppData?
        do {
            loaded = try await store.load()
        } catch {
            return CollectionAnswerContext(state: .unavailable, today: today)
        }

        guard let persisted = loaded else {
            return CollectionAnswerContext(state: .notConfigured, today: today)
        }

        var snapshot = persisted.snapshot
        if policy.shouldRefresh(mode: mode, snapshot: snapshot, today: today, now: currentTime) {
            snapshot = await refreshed(
                property: persisted.property,
                cachedSnapshot: snapshot,
                persisted: persisted,
                at: currentTime
            )
        }

        let completionState = (try? await completionStore.load()) ?? CompletionState()
        return Self.context(
            propertyDisplayName: persisted.property.displayName,
            snapshot: snapshot,
            completionState: completionState,
            today: today
        )
    }

    static func context(
        propertyDisplayName: String,
        snapshot: ScheduleSnapshot?,
        completionState: CompletionState,
        today: LocalDate
    ) -> CollectionAnswerContext {
        guard let snapshot else {
            return CollectionAnswerContext(
                state: .noUpcoming(propertyDisplayName: propertyDisplayName),
                today: today
            )
        }

        let upcoming = snapshot.upcoming(relativeTo: today)
        guard let next = upcoming.first else {
            return CollectionAnswerContext(
                state: .noUpcoming(propertyDisplayName: propertyDisplayName),
                fetchedAt: snapshot.fetchedAt,
                refreshErrorMessage: snapshot.lastRefreshError,
                today: today
            )
        }

        return CollectionAnswerContext(
            state: .scheduled(
                propertyDisplayName: propertyDisplayName,
                next: next,
                following: Array(upcoming.dropFirst())
            ),
            isNextPutOut: completionState.isPutOut(next.id),
            fetchedAt: snapshot.fetchedAt,
            refreshErrorMessage: snapshot.lastRefreshError,
            today: today
        )
    }

    /// A failure records the attempt but never discards the last good snapshot, matching
    /// `AppModel.refresh()`.
    private func refreshed(
        property: Property,
        cachedSnapshot: ScheduleSnapshot?,
        persisted: PersistedAppData,
        at date: Date
    ) async -> ScheduleSnapshot? {
        do {
            let snapshot = try await provider.schedule(for: property)
            await persist(snapshot, property: property, persisted: persisted, at: date)
            return snapshot
        } catch {
            guard let cachedSnapshot else { return nil }
            let recorded = cachedSnapshot.recordingRefreshFailure(
                at: date,
                message: AppModel.message(for: error)
            )
            await persist(recorded, property: property, persisted: persisted, at: date)
            return recorded
        }
    }

    private func persist(
        _ snapshot: ScheduleSnapshot,
        property: Property,
        persisted: PersistedAppData,
        at date: Date
    ) async {
        try? await store.save(
            PersistedAppData(
                property: property,
                snapshot: snapshot,
                propertyUpdatedAt: persisted.propertyUpdatedAt,
                settings: persisted.settings
            )
        )

        let payload = WidgetSchedulePayloadBuilder.make(
            property: property,
            snapshot: snapshot,
            now: date
        )

        // Best effort: the widget is never a reason to fail the answer.
        do {
            guard try await widgetPayloadStore.load() != payload else { return }
            try await widgetPayloadStore.save(payload)
            await widgetTimelineReloader.reloadCollectionWidget()
        } catch {
            return
        }
    }
}
