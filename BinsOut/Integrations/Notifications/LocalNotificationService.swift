import Foundation
import UserNotifications

enum NotificationPermissionStatus: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}

protocol NotificationScheduling: Sendable {
    func permissionStatus() async -> NotificationPermissionStatus
    func requestAuthorization(sound: Bool) async throws -> Bool
    func reconcile(_ reminders: [ScheduledReminder]) async throws
}

struct LocalNotificationService: NotificationScheduling {
    func permissionStatus() async -> NotificationPermissionStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .authorized, .provisional, .ephemeral:
            return .allowed
        case .denied:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestAuthorization(sound: Bool) async throws -> Bool {
        var options: UNAuthorizationOptions = [.alert]
        if sound { options.insert(.sound) }
        return try await UNUserNotificationCenter.current().requestAuthorization(options: options)
    }

    func reconcile(_ reminders: [ScheduledReminder]) async throws {
        let center = UNUserNotificationCenter.current()
        let desiredIDs = Set(reminders.map(\.id))
        let pending = await center.pendingNotificationRequests()
        let staleIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(SystemIdentifiers.notificationPrefix) && !desiredIDs.contains($0) }
        center.removePendingNotificationRequests(withIdentifiers: staleIDs)

        for reminder in reminders {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = reminder.usesSound ? .default : nil
            content.userInfo = ["occurrenceID": reminder.occurrenceID]

            var components = LocalDate.calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminder.fireDate
            )
            components.calendar = LocalDate.calendar
            components.timeZone = LocalDate.timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(
                UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
            )
        }
    }
}

struct NoopNotificationService: NotificationScheduling {
    func permissionStatus() async -> NotificationPermissionStatus { .notDetermined }
    func requestAuthorization(sound: Bool) async throws -> Bool { false }
    func reconcile(_ reminders: [ScheduledReminder]) async throws { }
}
