import Foundation

enum SystemIdentifiers {
    static let notificationPrefix = "bins-out.reminder."
    static let liveActivityPreviewOccurrenceID = "bins-out.live-activity-preview"
    static let liveActivityPreviewScheduleID = "bins-out.live-activity-preview"

    static func notification(for occurrenceID: String) -> String {
        notificationPrefix + occurrenceID
    }

    static func isLiveActivityPreview(scheduleID: String) -> Bool {
        scheduleID == liveActivityPreviewScheduleID
    }

    static func isLiveActivityPreview(occurrenceID: String) -> Bool {
        occurrenceID == liveActivityPreviewOccurrenceID
    }
}
