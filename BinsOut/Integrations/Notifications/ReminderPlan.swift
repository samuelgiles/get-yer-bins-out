import Foundation

struct ScheduledReminder: Equatable, Sendable, Identifiable {
    let id: String
    let occurrenceID: String
    let fireDate: Date
    let title: String
    let body: String
    let usesSound: Bool
}

enum ReminderPlanBuilder {
    static func reminders(
        snapshot: ScheduleSnapshot,
        settings: ReminderSettings,
        completionState: CompletionState,
        now: Date
    ) -> [ScheduledReminder] {
        guard settings.notificationsEnabled else { return [] }

        return snapshot.occurrences.compactMap { occurrence in
            guard !completionState.isPutOut(occurrence.id) else { return nil }
            let fireDate = occurrence.localDate
                .adding(days: -1)
                .date(hour: settings.notificationHour, minute: settings.notificationMinute)
            guard fireDate > now else { return nil }

            let names = occurrence.containers.map(\.sourceLabel).formatted(.list(type: .and))
            return ScheduledReminder(
                id: SystemIdentifiers.notification(for: occurrence.id),
                occurrenceID: occurrence.id,
                fireDate: fireDate,
                title: "Bins out tonight",
                body: "Put out \(names) for the scheduled collection tomorrow.",
                usesSound: settings.notificationSoundEnabled
            )
        }
        .prefix(32)
        .map { $0 }
    }
}
