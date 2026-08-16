import Foundation

enum AppEnvironment {
    @MainActor
    static func makeAppModel(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppModel {
        let provider: any CollectionProvider
        if environment["BINS_OUT_USE_FIXTURE"] == "1" {
            provider = FixtureCollectionProvider()
        } else {
            provider = BristolCollectionProvider(configuration: .officialWebsiteClient)
        }

        return AppModel(
            provider: provider,
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
