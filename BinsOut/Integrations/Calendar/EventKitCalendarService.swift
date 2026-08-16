import EventKit
import Foundation

enum CalendarSyncError: Error, LocalizedError {
    case accessDenied
    case calendarUnavailable
    case calendarReadOnly
    case missingEventIdentifier

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            "Full Calendar access is needed to keep selected-calendar events synchronized."
        case .calendarUnavailable:
            "The selected calendar is no longer available. Choose another writable calendar."
        case .calendarReadOnly:
            "The selected calendar can no longer be changed. Choose a writable calendar."
        case .missingEventIdentifier:
            "Calendar did not return an identifier for a saved event."
        }
    }
}

@MainActor
protocol CalendarSyncServicing: AnyObject {
    func permissionStatus() -> CalendarPermissionStatus
    func requestFullAccess() async throws -> Bool
    func preparePlan(
        snapshot: ScheduleSnapshot,
        state: CalendarSyncState,
        currentDate: LocalDate
    ) throws -> CalendarReconciliationPlan
    func apply(
        plan: CalendarReconciliationPlan,
        to state: CalendarSyncState,
        at date: Date
    ) throws -> CalendarSyncState
    func removeFutureManagedEvents(
        from state: CalendarSyncState,
        currentDate: LocalDate,
        at date: Date
    ) throws -> CalendarSyncState
}

@MainActor
final class EventKitCalendarService: CalendarSyncServicing {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    func permissionStatus() -> CalendarPermissionStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess, .authorized:
            return .allowed
        case .denied, .restricted, .writeOnly:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestFullAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    func preparePlan(
        snapshot: ScheduleSnapshot,
        state: CalendarSyncState,
        currentDate: LocalDate
    ) throws -> CalendarReconciliationPlan {
        guard permissionStatus() == .allowed else { throw CalendarSyncError.accessDenied }
        let calendar = try selectedCalendar(for: state)

        var records: [String: CalendarEventRecord] = [:]
        var recovered: [String: ManagedCalendarEventReference] = [:]
        for (occurrenceID, reference) in state.managedEventsByOccurrenceID {
            if let event = eventStore.event(withIdentifier: reference.eventIdentifier) {
                records[occurrenceID] = record(event, occurrenceID: occurrenceID)
            }
        }

        if let horizon = snapshot.authoritativeThrough {
            let predicate = eventStore.predicateForEvents(
                withStart: currentDate.date(hour: 0),
                end: horizon.adding(days: 1).date(hour: 0),
                calendars: [calendar]
            )
            for event in eventStore.events(matching: predicate) {
                guard let occurrenceID = Self.occurrenceID(from: event.url),
                      let eventIdentifier = event.eventIdentifier else { continue }
                records[occurrenceID] = record(event, occurrenceID: occurrenceID)
                recovered[occurrenceID] = ManagedCalendarEventReference(
                    eventIdentifier: eventIdentifier,
                    localDate: LocalDate(date: event.startDate)
                )
            }
        }

        guard let plan = CalendarReconciliationPlanner.plan(
            snapshot: snapshot,
            state: state,
            existingEvents: records,
            recoveredReferences: recovered,
            currentDate: currentDate
        ) else {
            throw CalendarSyncError.calendarUnavailable
        }
        return plan
    }

    func apply(
        plan: CalendarReconciliationPlan,
        to state: CalendarSyncState,
        at date: Date
    ) throws -> CalendarSyncState {
        guard permissionStatus() == .allowed else { throw CalendarSyncError.accessDenied }
        guard let calendar = eventStore.calendar(withIdentifier: plan.calendarIdentifier) else {
            throw CalendarSyncError.calendarUnavailable
        }
        guard calendar.allowsContentModifications else { throw CalendarSyncError.calendarReadOnly }

        var updatedState = state
        updatedState.managedEventsByOccurrenceID.merge(plan.recoveredReferences) { existing, _ in existing }
        updatedState.suppressedOccurrenceIDs.formUnion(plan.newlySuppressedOccurrenceIDs)
        for occurrenceID in plan.newlySuppressedOccurrenceIDs {
            updatedState.managedEventsByOccurrenceID.removeValue(forKey: occurrenceID)
        }

        for action in plan.actions {
            switch action {
            case .add(let descriptor):
                let event = EKEvent(eventStore: eventStore)
                configure(event, descriptor: descriptor, calendar: calendar)
                try eventStore.save(event, span: .thisEvent, commit: true)
                guard let eventIdentifier = event.eventIdentifier else {
                    throw CalendarSyncError.missingEventIdentifier
                }
                updatedState.managedEventsByOccurrenceID[descriptor.occurrenceID] =
                    ManagedCalendarEventReference(
                        eventIdentifier: eventIdentifier,
                        localDate: descriptor.localDate
                    )

            case .update(let descriptor, let eventIdentifier):
                guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
                    updatedState.managedEventsByOccurrenceID.removeValue(forKey: descriptor.occurrenceID)
                    updatedState.suppressedOccurrenceIDs.insert(descriptor.occurrenceID)
                    continue
                }
                configure(event, descriptor: descriptor, calendar: calendar)
                try eventStore.save(event, span: .thisEvent, commit: true)
                updatedState.managedEventsByOccurrenceID[descriptor.occurrenceID] =
                    ManagedCalendarEventReference(
                        eventIdentifier: event.eventIdentifier ?? eventIdentifier,
                        localDate: descriptor.localDate
                    )

            case .remove(let occurrenceID, let eventIdentifier, _):
                if let event = eventStore.event(withIdentifier: eventIdentifier) {
                    try eventStore.remove(event, span: .thisEvent, commit: true)
                }
                updatedState.managedEventsByOccurrenceID.removeValue(forKey: occurrenceID)
            }
        }

        updatedState.lastReconciledAt = date
        return updatedState
    }

    func removeFutureManagedEvents(
        from state: CalendarSyncState,
        currentDate: LocalDate,
        at date: Date
    ) throws -> CalendarSyncState {
        guard permissionStatus() == .allowed else { throw CalendarSyncError.accessDenied }
        var updatedState = state
        for (occurrenceID, reference) in state.managedEventsByOccurrenceID
        where reference.localDate >= currentDate {
            if let event = eventStore.event(withIdentifier: reference.eventIdentifier) {
                try eventStore.remove(event, span: .thisEvent, commit: true)
            }
            updatedState.managedEventsByOccurrenceID.removeValue(forKey: occurrenceID)
        }
        updatedState.isEnabled = false
        updatedState.lastReconciledAt = date
        return updatedState
    }

    private func selectedCalendar(for state: CalendarSyncState) throws -> EKCalendar {
        guard let identifier = state.selectedCalendarIdentifier,
              let calendar = eventStore.calendar(withIdentifier: identifier) else {
            throw CalendarSyncError.calendarUnavailable
        }
        guard calendar.allowsContentModifications else { throw CalendarSyncError.calendarReadOnly }
        return calendar
    }

    private func record(_ event: EKEvent, occurrenceID: String) -> CalendarEventRecord {
        CalendarEventRecord(
            occurrenceID: occurrenceID,
            eventIdentifier: event.eventIdentifier ?? "",
            localDate: LocalDate(date: event.startDate),
            title: event.title ?? "",
            notes: event.notes ?? "",
            isAllDay: event.isAllDay,
            calendarIdentifier: event.calendar.calendarIdentifier
        )
    }

    private func configure(
        _ event: EKEvent,
        descriptor: CalendarEventDescriptor,
        calendar: EKCalendar
    ) {
        event.calendar = calendar
        event.title = descriptor.title
        event.notes = descriptor.notes
        event.startDate = descriptor.localDate.date(hour: 0)
        event.endDate = descriptor.localDate.adding(days: 1).date(hour: 0)
        event.isAllDay = true
        event.url = Self.eventURL(for: descriptor.occurrenceID)
    }

    private static func eventURL(for occurrenceID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "binsout"
        components.host = "collection"
        components.queryItems = [URLQueryItem(name: "occurrence", value: occurrenceID)]
        return components.url
    }

    private static func occurrenceID(from url: URL?) -> String? {
        guard let url,
              url.scheme == "binsout",
              url.host == "collection" else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "occurrence" })?
            .value
    }
}

@MainActor
final class NoopCalendarService: CalendarSyncServicing {
    func permissionStatus() -> CalendarPermissionStatus { .notDetermined }
    func requestFullAccess() async throws -> Bool { false }

    func preparePlan(
        snapshot: ScheduleSnapshot,
        state: CalendarSyncState,
        currentDate: LocalDate
    ) throws -> CalendarReconciliationPlan {
        throw CalendarSyncError.accessDenied
    }

    func apply(
        plan: CalendarReconciliationPlan,
        to state: CalendarSyncState,
        at date: Date
    ) throws -> CalendarSyncState {
        throw CalendarSyncError.accessDenied
    }

    func removeFutureManagedEvents(
        from state: CalendarSyncState,
        currentDate: LocalDate,
        at date: Date
    ) throws -> CalendarSyncState {
        throw CalendarSyncError.accessDenied
    }
}
