import XCTest
@testable import BinsOut

final class CalendarReconciliationTests: XCTestCase {
    func testRecyclingOnlyTitleAndNotesIncludeContainerDetails() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(
            containerSchedules: [
                ("black-recycling", "45L Black Recycling Box", [date]),
                ("blue-bag", "90L Blue Bag", [date]),
            ]
        )
        let descriptor = try XCTUnwrap(
            snapshot.occurrences.first.map { CalendarEventDescriptor(occurrence: $0, snapshot: snapshot) }
        )

        XCTAssertEqual(descriptor.title, "♻️ Recycling")
        XCTAssertTrue(descriptor.notes.contains("• 45L Black Recycling Box"))
        XCTAssertTrue(descriptor.notes.contains("• 90L Blue Bag"))
        XCTAssertTrue(descriptor.notes.contains("Place containers at the boundary before 06:00."))
        XCTAssertTrue(descriptor.notes.contains("Source: Fixture."))
        XCTAssertTrue(descriptor.notes.contains("Last refreshed:"))
    }

    func testRecyclingAndGeneralWasteUsesSimplifiedTitle() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(
            containerSchedules: [
                ("general", "180L General Waste", [date]),
                ("green-recycling", "55L Green Recycling Box", [date]),
            ]
        )

        let descriptor = try XCTUnwrap(
            snapshot.occurrences.first.map { CalendarEventDescriptor(occurrence: $0, snapshot: snapshot) }
        )

        XCTAssertEqual(descriptor.title, "🗑️ Recycling + Bins")
    }

    func testFoodAndUnknownContainersStayInNotesWithoutComplicatingRecyclingTitle() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(
            containerSchedules: [
                ("green-recycling", "55L Green Recycling Box", [date]),
                ("food", "23L Food Waste Bin", [date]),
                ("future-container", "New trial container", [date]),
            ]
        )

        let event = descriptor(for: snapshot)

        XCTAssertEqual(event.title, "♻️ Recycling")
        XCTAssertTrue(event.notes.contains("• 23L Food Waste Bin"))
        XCTAssertTrue(event.notes.contains("• 55L Green Recycling Box"))
        XCTAssertTrue(event.notes.contains("• New trial container"))
    }

    func testOtherContainerCombinationsHaveDeterministicTitles() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let garden = try makeSnapshot(
            containerSchedules: [("garden", "Garden waste", [date])]
        )
        let food = try makeSnapshot(
            containerSchedules: [("food", "23L Food Waste Bin", [date])]
        )
        let general = try makeSnapshot(
            containerSchedules: [("general", "180L General Waste", [date])]
        )
        let mixed = try makeSnapshot(
            containerSchedules: [
                ("garden", "Garden waste", [date]),
                ("food", "23L Food Waste Bin", [date]),
            ]
        )

        XCTAssertEqual(descriptor(for: garden).title, "🍃 Garden waste")
        XCTAssertEqual(descriptor(for: food).title, "🍽️ Food waste")
        XCTAssertEqual(descriptor(for: general).title, "🗑️ Bins")
        XCTAssertEqual(descriptor(for: mixed).title, "🍃 Garden waste")
    }

    func testPlansEveryFutureOccurrenceReturnedByProviderWithoutInventingRecurrence() throws {
        let currentDate = try LocalDate(year: 2026, month: 8, day: 16)
        let firstDate = currentDate.adding(days: 7)
        let farFutureDate = currentDate.adding(days: 7 * 30)
        let snapshot = try makeSnapshot(dates: [firstDate, farFutureDate])
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: snapshot,
            state: state,
            existingEvents: [:],
            recoveredReferences: [:],
            currentDate: currentDate
        ))

        XCTAssertEqual(snapshot.authoritativeThrough, farFutureDate)
        XCTAssertEqual(plan.additions, 2)
        XCTAssertEqual(plan.updates, 0)
        XCTAssertEqual(plan.removals, 0)
    }

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

    func testDateChangeRemovesOldManagedEventAndAddsNewOne() throws {
        let currentDate = try LocalDate(year: 2026, month: 8, day: 16)
        let oldDate = currentDate.adding(days: 5)
        let newDate = currentDate.adding(days: 7)
        let oldSnapshot = try makeSnapshot(dates: [oldDate])
        let newSnapshot = try makeSnapshot(dates: [newDate])
        let oldOccurrence = try XCTUnwrap(oldSnapshot.occurrences.first)
        let oldDescriptor = CalendarEventDescriptor(occurrence: oldOccurrence, snapshot: oldSnapshot)
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        state.managedEventsByOccurrenceID[oldOccurrence.id] = ManagedCalendarEventReference(
            eventIdentifier: "old-event",
            localDate: oldDate
        )

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: newSnapshot,
            state: state,
            existingEvents: [
                oldOccurrence.id: CalendarEventRecord(
                    occurrenceID: oldOccurrence.id,
                    eventIdentifier: "old-event",
                    localDate: oldDate,
                    title: oldDescriptor.title,
                    notes: oldDescriptor.notes,
                    isAllDay: true,
                    calendarIdentifier: "calendar"
                ),
            ],
            recoveredReferences: [:],
            currentDate: currentDate
        ))

        XCTAssertEqual(plan.additions, 1)
        XCTAssertEqual(plan.updates, 0)
        XCTAssertEqual(plan.removals, 1)
    }

    func testMissingProviderOccurrenceRemovesExistingManagedEvent() throws {
        let currentDate = try LocalDate(year: 2026, month: 8, day: 16)
        let futureDate = currentDate.adding(days: 7)
        let previousSnapshot = try makeSnapshot(dates: [futureDate])
        let emptySnapshot = try makeSnapshot(dates: [])
        let occurrence = try XCTUnwrap(previousSnapshot.occurrences.first)
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        state.managedEventsByOccurrenceID[occurrence.id] = ManagedCalendarEventReference(
            eventIdentifier: "event",
            localDate: futureDate
        )

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: emptySnapshot,
            state: state,
            existingEvents: [
                occurrence.id: CalendarEventRecord(
                    occurrenceID: occurrence.id,
                    eventIdentifier: "event",
                    localDate: futureDate,
                    title: "🗑️ Bins",
                    notes: "",
                    isAllDay: true,
                    calendarIdentifier: "calendar"
                ),
            ],
            recoveredReferences: [:],
            currentDate: currentDate
        ))

        XCTAssertEqual(plan.removals, 1)
    }

    func testContainerChangeRemovesOldManagedEventAndAddsReplacement() throws {
        let currentDate = try LocalDate(year: 2026, month: 8, day: 16)
        let date = currentDate.adding(days: 7)
        let oldSnapshot = try makeSnapshot(
            containerSchedules: [("food", "23L Food Waste Bin", [date])]
        )
        let newSnapshot = try makeSnapshot(
            containerSchedules: [("general", "180L General Waste", [date])]
        )
        let oldOccurrence = try XCTUnwrap(oldSnapshot.occurrences.first)
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        state.managedEventsByOccurrenceID[oldOccurrence.id] = ManagedCalendarEventReference(
            eventIdentifier: "old-event",
            localDate: date
        )

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: newSnapshot,
            state: state,
            existingEvents: [
                oldOccurrence.id: CalendarEventRecord(
                    occurrenceID: oldOccurrence.id,
                    eventIdentifier: "old-event",
                    localDate: date,
                    title: descriptor(for: oldSnapshot).title,
                    notes: descriptor(for: oldSnapshot).notes,
                    isAllDay: true,
                    calendarIdentifier: "calendar"
                ),
            ],
            recoveredReferences: [:],
            currentDate: currentDate
        ))

        XCTAssertEqual(plan.additions, 1)
        XCTAssertEqual(plan.removals, 1)
        XCTAssertEqual(plan.updates, 0)
    }

    func testMatchingManagedEventProducesNoChanges() throws {
        let currentDate = try LocalDate(year: 2026, month: 8, day: 16)
        let date = currentDate.adding(days: 7)
        let snapshot = try makeSnapshot(dates: [date])
        let occurrence = try XCTUnwrap(snapshot.occurrences.first)
        let descriptor = CalendarEventDescriptor(occurrence: occurrence, snapshot: snapshot)
        var state = CalendarSyncState()
        state.isEnabled = true
        state.selectedCalendarIdentifier = "calendar"
        state.managedEventsByOccurrenceID[occurrence.id] = ManagedCalendarEventReference(
            eventIdentifier: "event",
            localDate: date
        )

        let plan = try XCTUnwrap(CalendarReconciliationPlanner.plan(
            snapshot: snapshot,
            state: state,
            existingEvents: [
                occurrence.id: CalendarEventRecord(
                    occurrenceID: occurrence.id,
                    eventIdentifier: "event",
                    localDate: date,
                    title: descriptor.title,
                    notes: descriptor.notes,
                    isAllDay: true,
                    calendarIdentifier: "calendar"
                ),
            ],
            recoveredReferences: [:],
            currentDate: currentDate
        ))

        XCTAssertTrue(plan.actions.isEmpty)
        XCTAssertTrue(plan.newlySuppressedOccurrenceIDs.isEmpty)
    }

    private func makeSnapshot(dates: [LocalDate]) throws -> ScheduleSnapshot {
        try makeSnapshot(containerSchedules: [
            ("food", "Food waste bin", dates),
        ])
    }

    private func makeSnapshot(
        containerSchedules: [(sourceID: String, sourceLabel: String, dates: [LocalDate])]
    ) throws -> ScheduleSnapshot {
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
            containers: containerSchedules.map { schedule in
                ProviderContainerSchedule(
                    sourceID: schedule.sourceID,
                    sourceLabel: schedule.sourceLabel,
                    dates: schedule.dates
                )
            }
        )
    }

    private func descriptor(for snapshot: ScheduleSnapshot) -> CalendarEventDescriptor {
        CalendarEventDescriptor(occurrence: snapshot.occurrences[0], snapshot: snapshot)
    }
}
