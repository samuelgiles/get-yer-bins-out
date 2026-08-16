import XCTest
@testable import BinsOut

final class ScheduleNormalizerTests: XCTestCase {
    private let property = Property(
        id: UUID(uuidString: "A11CE000-0000-4000-8000-000000000001")!,
        council: .bristolCityCouncil,
        uprn: "123456789",
        displayName: "Home"
    )

    func testGroupsDifferentContainersOnTheSameLocalDate() throws {
        let firstDate = try LocalDate(year: 2026, month: 8, day: 21)
        let secondDate = try LocalDate(year: 2026, month: 8, day: 28)
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "test",
            providerDisplayName: "Test provider",
            fetchedAt: Date(timeIntervalSince1970: 100),
            containers: [
                ProviderContainerSchedule(sourceID: "green", sourceLabel: "Green recycling box", dates: [firstDate, secondDate]),
                ProviderContainerSchedule(sourceID: "food", sourceLabel: "Brown food bin", dates: [firstDate, firstDate]),
            ]
        )

        XCTAssertEqual(snapshot.occurrences.count, 2)
        XCTAssertEqual(snapshot.occurrences[0].localDate, firstDate)
        XCTAssertEqual(snapshot.occurrences[0].containers.map(\.id).sorted(), ["food", "green"])
        XCTAssertEqual(snapshot.occurrences[1].containers.map(\.id), ["green"])
    }

    func testOccurrenceIdentityIsStableAcrossProviderOrdering() throws {
        let date = try LocalDate(year: 2026, month: 8, day: 21)
        let green = ContainerKind(sourceID: "green", sourceLabel: "Green recycling box")
        let food = ContainerKind(sourceID: "food", sourceLabel: "Brown food bin")

        let first = CollectionOccurrence(propertyID: property.id, localDate: date, containers: [green, food])
        let second = CollectionOccurrence(propertyID: property.id, localDate: date, containers: [food, green])

        XCTAssertEqual(first.id, second.id)
    }

    func testUpcomingWindowUsesLocalCalendarWeeksAndExclusiveEndDate() throws {
        let today = try LocalDate(year: 2026, month: 3, day: 1)
        let dates = [-1, 0, 41, 42, 167, 168].map(today.adding(days:))
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "test",
            providerDisplayName: "Test provider",
            fetchedAt: today.dateAtNoon,
            containers: [
                ProviderContainerSchedule(
                    sourceID: "food",
                    sourceLabel: "Food waste bin",
                    dates: dates
                ),
            ]
        )

        XCTAssertEqual(
            snapshot.upcoming(relativeTo: today, withinWeeks: 6).map(\.localDate),
            [today, today.adding(days: 41)]
        )
        XCTAssertEqual(
            snapshot.upcoming(relativeTo: today, withinWeeks: 24).map(\.localDate),
            [today, today.adding(days: 41), today.adding(days: 42), today.adding(days: 167)]
        )
    }

    func testUpcomingWindowRejectsNonPositiveWeekCount() throws {
        let today = try LocalDate(year: 2026, month: 8, day: 16)
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "test",
            providerDisplayName: "Test provider",
            fetchedAt: today.dateAtNoon,
            containers: [
                ProviderContainerSchedule(
                    sourceID: "food",
                    sourceLabel: "Food waste bin",
                    dates: [today]
                ),
            ]
        )

        XCTAssertTrue(snapshot.upcoming(relativeTo: today, withinWeeks: 0).isEmpty)
        XCTAssertTrue(snapshot.upcoming(relativeTo: today, withinWeeks: -1).isEmpty)
    }
}
