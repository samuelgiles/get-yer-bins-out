import XCTest
@testable import BinsOut

final class ReminderAndActivityPlanTests: XCTestCase {
    func testReminderUsesLondonEveningBeforeAndCompletionCancelsIt() throws {
        let snapshot = try makeSnapshot(collectionDate: LocalDate(year: 2026, month: 8, day: 21))
        let now = try LocalDate(year: 2026, month: 8, day: 20).date(hour: 12)
        var settings = ReminderSettings()
        settings.notificationsEnabled = true

        let reminders = ReminderPlanBuilder.reminders(
            snapshot: snapshot,
            settings: settings,
            completionState: CompletionState(),
            now: now
        )

        let reminder = try XCTUnwrap(reminders.first)
        let components = LocalDate.calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminder.fireDate
        )
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 8)
        XCTAssertEqual(components.day, 20)
        XCTAssertEqual(components.hour, 17)
        XCTAssertEqual(components.minute, 45)

        var completion = CompletionState()
        completion.markPutOut(snapshot.occurrences[0].id, at: now)
        XCTAssertTrue(
            ReminderPlanBuilder.reminders(
                snapshot: snapshot,
                settings: settings,
                completionState: completion,
                now: now
            ).isEmpty
        )
    }

    func testLiveActivityCoversSixPMToNineAMInTwoSubEightHourSegments() throws {
        let collectionDate = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(collectionDate: collectionDate)
        let now = try LocalDate(year: 2026, month: 8, day: 20).date(hour: 12)
        var settings = ReminderSettings()
        settings.liveActivitiesEnabled = true

        let schedule = LiveActivityPlanBuilder.schedule(
            snapshot: snapshot,
            settings: settings,
            completionState: CompletionState(),
            now: now
        )

        XCTAssertEqual(schedule.segments.count, 2)
        XCTAssertEqual(schedule.segments.first?.startDate, collectionDate.adding(days: -1).date(hour: 18))
        XCTAssertEqual(schedule.segments.last?.staleDate, collectionDate.date(hour: 9))
        XCTAssertTrue(schedule.segments.allSatisfy {
            $0.staleDate.timeIntervalSince($0.startDate) <= 8 * 60 * 60
        })
    }

    func testLiveActivitySegmentsRespectEightHoursAcrossGMTReturn() throws {
        let collectionDate = try LocalDate(year: 2026, month: 10, day: 25)
        let snapshot = try makeSnapshot(collectionDate: collectionDate)
        let now = collectionDate.adding(days: -1).date(hour: 12)
        var settings = ReminderSettings()
        settings.liveActivitiesEnabled = true

        let schedule = LiveActivityPlanBuilder.schedule(
            snapshot: snapshot,
            settings: settings,
            completionState: CompletionState(),
            now: now
        )

        XCTAssertEqual(schedule.segments.count, 2)
        XCTAssertTrue(schedule.segments.allSatisfy {
            $0.staleDate.timeIntervalSince($0.startDate) <= 8 * 60 * 60
        })
        XCTAssertEqual(schedule.segments.last?.staleDate, collectionDate.date(hour: 9))
    }

    func testLiveActivityPreviewUsesNextSavedCollectionWithoutRealOccurrenceIdentity() throws {
        let collectionDate = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = try makeSnapshot(collectionDate: collectionDate)
        let now = collectionDate.adding(days: -1).date(hour: 12)

        let segment = try XCTUnwrap(
            LiveActivityPlanBuilder.previewSegment(snapshot: snapshot, now: now)
        )

        XCTAssertEqual(segment.id, SystemIdentifiers.liveActivityPreviewScheduleID)
        XCTAssertEqual(segment.occurrenceID, SystemIdentifiers.liveActivityPreviewOccurrenceID)
        XCTAssertNotEqual(segment.occurrenceID, snapshot.occurrences[0].id)
        XCTAssertEqual(segment.collectionDate, collectionDate.fullDescription)
        XCTAssertEqual(segment.containers.map(\.name), ["Food waste bin"])
        XCTAssertEqual(segment.startDate, now)
        XCTAssertEqual(
            segment.staleDate,
            now.addingTimeInterval(LiveActivityPlanBuilder.previewDuration)
        )
    }

    private func makeSnapshot(collectionDate: LocalDate) throws -> ScheduleSnapshot {
        let property = Property(
            id: try XCTUnwrap(UUID(uuidString: "A1710170-0000-4000-8000-000000000001")),
            council: .bristolCityCouncil,
            uprn: "001234567890",
            displayName: "Test property"
        )
        return ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "fixture",
            providerDisplayName: "Fixture",
            fetchedAt: collectionDate.adding(days: -2).date(hour: 12),
            containers: [
                ProviderContainerSchedule(
                    sourceID: "food",
                    sourceLabel: "Food waste bin",
                    dates: [collectionDate]
                ),
            ]
        )
    }
}
