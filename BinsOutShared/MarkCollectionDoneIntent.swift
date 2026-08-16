#if !targetEnvironment(macCatalyst)
import ActivityKit
import AppIntents
import Foundation
import UserNotifications
import WidgetKit

struct MarkCollectionDoneIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Bins out"
    static let description = IntentDescription("Marks this collection’s containers as put out.")
    static let supportedModes: IntentModes = .background
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Collection")
    var occurrenceID: String

    init() { }

    init(occurrenceID: String) {
        self.occurrenceID = occurrenceID
    }

    func perform() async throws -> some IntentResult {
        if SystemIdentifiers.isLiveActivityPreview(occurrenceID: occurrenceID) {
            await LiveActivityCoordinator().stopPreview()
            return .result()
        }

        let completionStore = FileCompletionStore()
        var completionState = try await completionStore.load()
        completionState.markPutOut(occurrenceID, at: .now)
        try await completionStore.save(completionState)

        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [SystemIdentifiers.notification(for: occurrenceID)]
        )

        for activity in Activity<CollectionActivityAttributes>.activities
        where activity.attributes.occurrenceID == occurrenceID {
            let content = ActivityContent(
                state: CollectionActivityAttributes.ContentState(isPutOut: true),
                staleDate: nil
            )
            await activity.end(content, dismissalPolicy: .immediate)
        }

        WidgetCenter.shared.reloadAllTimelines()

        let schedule = try await FileSharedActivityScheduleStore().load()
        _ = try await LiveActivityCoordinator().reconcile(
            schedule: schedule,
            completionState: completionState
        )

        return .result()
    }
}
#endif
