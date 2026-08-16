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
        title = Self.title(for: occurrence.containers)
        notes = Self.notes(for: occurrence.containers, snapshot: snapshot)
    }

    private static func title(for containers: [ContainerKind]) -> String {
        let categories = Set(containers.map(ContainerCategory.init))
        let hasRecycling = categories.contains(.recycling)
        let hasGeneralWaste = categories.contains(.generalWaste)

        if hasRecycling, hasGeneralWaste {
            return "🗑️ Recycling + Bins"
        }
        if hasRecycling {
            return "♻️ Recycling"
        }
        if hasGeneralWaste {
            return "🗑️ Bins"
        }
        if categories.contains(.garden) {
            return "🍃 Garden waste"
        }
        if categories.contains(.food) {
            return "🍽️ Food waste"
        }
        return "🗓️ Collection"
    }

    private static func notes(for containers: [ContainerKind], snapshot: ScheduleSnapshot) -> String {
        let containerList = containers
            .map(\.sourceLabel)
            .map { "• \($0)" }
            .joined(separator: "\n")
        let lastRefreshed = snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)

        return """
        Scheduled collection

        Containers:
        \(containerList)

        Place containers at the boundary before 06:00.
        Source: \(snapshot.providerDisplayName).
        Last refreshed: \(lastRefreshed).
        """
    }

    private enum ContainerCategory: Hashable {
        case recycling
        case generalWaste
        case garden
        case food
        case other

        init(_ container: ContainerKind) {
            let label = container.sourceLabel.lowercased()
            if label.contains("recycl") || label.contains("blue bag") {
                self = .recycling
            } else if label.contains("garden") {
                self = .garden
            } else if label.contains("food") || label.contains("brown") {
                self = .food
            } else if label.contains("general") || label.contains("refuse") || label.contains("wheelie") {
                self = .generalWaste
            } else {
                self = .other
            }
        }
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

        // The provider snapshot is the only authority for how far ahead to create
        // events. We intentionally do not synthesize a recurring series.
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
