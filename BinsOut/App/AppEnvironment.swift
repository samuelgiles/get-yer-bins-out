import Foundation

enum AppEnvironment {
    static func makeProvider(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> any CollectionProvider {
        guard environment["BINS_OUT_USE_FIXTURE"] != "1" else {
            return FixtureCollectionProvider()
        }
        return BristolCollectionProvider(configuration: .officialWebsiteClient)
    }

    /// Built once and reused across intent invocations. The short timeout matters:
    /// `URLSession.shared` waits 60 seconds, far longer than an intent's execution budget.
    static let intentProvider: any CollectionProvider = {
        guard ProcessInfo.processInfo.environment["BINS_OUT_USE_FIXTURE"] != "1" else {
            return FixtureCollectionProvider()
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = intentRequestTimeout
        configuration.timeoutIntervalForResource = intentRequestTimeout
        return BristolCollectionProvider(
            session: URLSession(configuration: configuration),
            configuration: .officialWebsiteClient
        )
    }()

    private static let intentRequestTimeout: TimeInterval = 10

    @MainActor
    static func makeAppModel(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppModel {
        AppModel(
            provider: makeProvider(environment: environment),
            store: FileAppDataStore(),
            propertySyncStore: KeychainPropertySyncStore(),
            completionStore: FileCompletionStore(),
            activityScheduleStore: FileSharedActivityScheduleStore(),
            notificationService: LocalNotificationService(),
            liveActivityService: ActivityKitLiveActivityService(),
            calendarService: EventKitCalendarService()
        )
    }
}
