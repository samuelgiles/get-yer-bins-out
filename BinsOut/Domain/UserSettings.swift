import Foundation

struct ReminderSettings: Codable, Equatable, Sendable {
    var notificationsEnabled = false
    var notificationHour = 17
    var notificationMinute = 45
    var notificationSoundEnabled = true
    var liveActivitiesEnabled = false

    var notificationTime: Date {
        var components = DateComponents()
        components.calendar = LocalDate.calendar
        components.timeZone = LocalDate.timeZone
        components.year = 2001
        components.month = 1
        components.day = 1
        components.hour = notificationHour
        components.minute = notificationMinute
        return LocalDate.calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }
}

struct CalendarSyncState: Codable, Equatable, Sendable {
    var isEnabled = false
    var selectedCalendarIdentifier: String?
    var selectedCalendarTitle: String?
    var managedEventsByOccurrenceID: [String: ManagedCalendarEventReference] = [:]
    var suppressedOccurrenceIDs: Set<String> = []
    var lastReconciledAt: Date?
}

struct ManagedCalendarEventReference: Codable, Equatable, Sendable {
    let eventIdentifier: String
    let localDate: LocalDate
}

struct UserSettings: Codable, Equatable, Sendable {
    var reminders = ReminderSettings()
    var calendar = CalendarSyncState()
}
