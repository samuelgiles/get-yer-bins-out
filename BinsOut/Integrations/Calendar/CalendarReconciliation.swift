import Foundation

enum CalendarPermissionStatus: Equatable, Sendable {
    case notDetermined
    case allowed
    case denied
}

struct CalendarEventRecord: Equatable, Sendable {
    let occurrenceID: String
    let eventIdentifier: String
    let localDate: LocalDate
    let title: String
    let notes: String
    let isAllDay: Bool
    let calendarIdentifier: String
}

struct CalendarEventDescriptor: Equatable, Sendable {
    let occurrenceID: String
    let localDate: LocalDate
    let title: String
    let notes: String

    init(occurrence: CollectionOccurrence, snapshot: ScheduleSnapshot) {
        occurrenceID = occurrence.id
        localDate = occurrence.localDate
        let names = occurrence.containers.map(\.sourceLabel).formatted(.list(type: .and))
        title = "Bins: \(names)"
        notes = "Scheduled collection · place at the boundary before 06:00. Source: \(snapshot.providerDisplayName). Last refreshed \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))."
    }
}

enum CalendarReconciliationAction: Equatable, Sendable {
    case add(CalendarEventDescriptor)
    case update(CalendarEventDescriptor, eventIdentifier: String)
    case remove(occurrenceID: String, eventIdentifier: String, localDate: LocalDate)
}

struct CalendarReconciliationPlan: Equatable, Sendable {
    let calendarIdentifier: String
    let actions: [CalendarReconciliationAction]
    let recoveredReferences: [String: ManagedCalendarEventReference]
    let newlySuppressedOccurrenceIDs: Set<String>

    var additions: Int { actions.count { if case .add = $0 { true } else { false } } }
    var updates: Int { actions.count { if case .update = $0 { true } else { false } } }
    var removals: Int { actions.count { if case .remove = $0 { true } else { false } } }
    var totalChanges: Int { actions.count }
}

enum CalendarReconciliationPlanner {
    static func plan(
        snapshot: ScheduleSnapshot,
        state: CalendarSyncState,
        existingEvents: [String: CalendarEventRecord],
        recoveredReferences: [String: ManagedCalendarEventReference],
        currentDate: LocalDate
    ) -> CalendarReconciliationPlan? {
        guard let calendarIdentifier = state.selectedCalendarIdentifier else { return nil }

        let desiredOccurrences = snapshot.occurrences.filter { $0.localDate >= currentDate }
        let desiredByID = Dictionary(uniqueKeysWithValues: desiredOccurrences.map { ($0.id, $0) })
        var references = state.managedEventsByOccurrenceID
        references.merge(recoveredReferences) { existing, _ in existing }
        var actions: [CalendarReconciliationAction] = []
        var newlySuppressed: Set<String> = []

        for occurrence in desiredOccurrences {
            let descriptor = CalendarEventDescriptor(occurrence: occurrence, snapshot: snapshot)
            if let reference = references[occurrence.id] {
                if let existing = existingEvents[occurrence.id] {
                    if existing.localDate != descriptor.localDate
                        || existing.title != descriptor.title
                        || existing.notes != descriptor.notes
                        || !existing.isAllDay
                        || existing.calendarIdentifier != calendarIdentifier {
                        actions.append(.update(descriptor, eventIdentifier: reference.eventIdentifier))
                    }
                } else if state.managedEventsByOccurrenceID[occurrence.id] != nil {
                    newlySuppressed.insert(occurrence.id)
                } else if !state.suppressedOccurrenceIDs.contains(occurrence.id) {
                    actions.append(.add(descriptor))
                }
            } else if !state.suppressedOccurrenceIDs.contains(occurrence.id) {
                actions.append(.add(descriptor))
            }
        }

        for (occurrenceID, reference) in references
        where desiredByID[occurrenceID] == nil && reference.localDate >= currentDate {
            if existingEvents[occurrenceID] != nil {
                actions.append(.remove(
                    occurrenceID: occurrenceID,
                    eventIdentifier: reference.eventIdentifier,
                    localDate: reference.localDate
                ))
            }
        }

        return CalendarReconciliationPlan(
            calendarIdentifier: calendarIdentifier,
            actions: actions,
            recoveredReferences: recoveredReferences,
            newlySuppressedOccurrenceIDs: newlySuppressed
        )
    }
}
