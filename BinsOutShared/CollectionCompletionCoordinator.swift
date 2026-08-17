#if !targetEnvironment(macCatalyst)
import ActivityKit
import Foundation
import UserNotifications
import WidgetKit

/// Records "these containers are out" for both the Live Activity button and the Siri
/// snippet button. A local user action only; it never means Bristol completed a collection.
struct CollectionCompletionCoordinator: Sendable {
    private let completionStore: any CompletionStoring
    private let activityScheduleStore: any SharedActivityScheduleStoring

    init(
        completionStore: any CompletionStoring = FileCompletionStore(),
        activityScheduleStore: any SharedActivityScheduleStoring = FileSharedActivityScheduleStore()
    ) {
        self.completionStore = completionStore
        self.activityScheduleStore = activityScheduleStore
    }

    /// Returns `false` for the Live Activity preview, which only needs dismissing.
    @discardableResult
    func markPutOut(occurrenceID: String, at date: Date = .now) async throws -> Bool {
        if SystemIdentifiers.isLiveActivityPreview(occurrenceID: occurrenceID) {
            await LiveActivityCoordinator().stopPreview()
            return false
        }

        var completionState = try await completionStore.load()
        completionState.markPutOut(occurrenceID, at: date)
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

        let schedule = try await activityScheduleStore.load()
        _ = try await LiveActivityCoordinator().reconcile(
            schedule: schedule,
            completionState: completionState
        )

        return true
    }
}
#endif
