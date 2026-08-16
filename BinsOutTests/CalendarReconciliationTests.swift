import XCTest
@testable import BinsOut

final class CalendarReconciliationTests: XCTestCase {
    func testPlansAddsUpdatesAndRemovalWithoutRecurrence() throws {
        let currentDate = try LocalDate(year: 2026, month: 8, day: 16)
        let firstDate = try LocalDate(year: 2026, month: 8, day: 21)
        let secondDate = try LocalDate(year: 2026, month: 8, day: 28)
        let removedDate = try LocalDate(year: 2026, month: 8, day: 22)
        let snapshot = try makeSnapshot(dates: [firstDate, secondDate])
        let first = snapshot.occurrences[0]
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        state.managedEventsByOccurrenceID[first.id] = ManagedCalendarEventReference(
            eventIdentifier: "event-one",
            localDate: firstDate
        )
        state.managedEventsByOccurrenceID["removed"] = ManagedCalendarEventReference(
            eventIdentifier: "event-removed",
            localDate: removedDate
        )
        let existing: [String: CalendarEventRecord] = [
            first.id: CalendarEventRecord(
                occurrenceID: first.id,
                eventIdentifier: "event-one",
                localDate: firstDate,
                title: "Old title",
                notes: "Old notes",
                isAllDay: false,
                calendarIdentifier: "calendar"
            ),
            "removed": CalendarEventRecord(
                occurrenceID: "removed",
                eventIdentifier: "event-removed",
                localDate: removedDate,
                title: "Old collection",
                notes: "",
                isAllDay: true,
                calendarIdentifier: "calendar"
            ),
        ]

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: snapshot,
            state: state,
            existingEvents: existing,
            recoveredReferences: [:],
            currentDate: currentDate
        ))

        XCTAssertEqual(plan.additions, 1)
        XCTAssertEqual(plan.updates, 1)
        XCTAssertEqual(plan.removals, 1)
    }

    func testMissingPreviouslyManagedEventIsSuppressedInsteadOfRecreated() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(dates: [date])
        let occurrence = snapshot.occurrences[0]
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        state.managedEventsByOccurrenceID[occurrence.id] = ManagedCalendarEventReference(
            eventIdentifier: "deleted-event",
            localDate: date
        )

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: snapshot,
            state: state,
            existingEvents: [:],
            recoveredReferences: [:],
            currentDate: date.adding(days: -1)
        ))

        XCTAssertEqual(plan.additions, 0)
        XCTAssertEqual(plan.newlySuppressedOccurrenceIDs, [occurrence.id])
    }

    func testRecoveredEventPreventsDuplicateAfterMappingLoss() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(dates: [date])
        let occurrence = snapshot.occurrences[0]
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        let descriptor = CalendarEventDescriptor(occurrence: occurrence, snapshot: snapshot)
        let reference = ManagedCalendarEventReference(eventIdentifier: "recovered", localDate: date)
        let record = CalendarEventRecord(
            occurrenceID: occurrence.id,
            eventIdentifier: "recovered",
            localDate: date,
            title: descriptor.title,
            notes: descriptor.notes,
            isAllDay: true,
            calendarIdentifier: "calendar"
        )

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: snapshot,
            state: state,
            existingEvents: [occurrence.id: record],
            recoveredReferences: [occurrence.id: reference],
            currentDate: date.adding(days: -1)
        ))

        XCTAssertTrue(plan.actions.isEmpty)
        XCTAssertEqual(plan.recoveredReferences[occurrence.id], reference)
    }

    private func makeSnapshot(dates: [LocalDate]) throws -> ScheduleSnapshot {
        let property = Property(
            id: try XCTUnwrap(UUID(uuidString: "CA1E0DA0-0000-4000-8000-000000000001")),
            council: .bristolCityCouncil,
            uprn: "001234567890",
            displayName: "Test property"
        )
        return ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "fixture",
            providerDisplayName: "Fixture",
            fetchedAt: Date(timeIntervalSince1970: 1_786_867_200),
            containers: [
                ProviderContainerSchedule(
                    sourceID: "food",
                    sourceLabel: "Food waste bin",
                    dates: dates
                ),
            ]
        )
    }
}
