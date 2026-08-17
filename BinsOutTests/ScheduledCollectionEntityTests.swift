import XCTest
@testable import BinsOut

final class ScheduledCollectionEntityTests: XCTestCase {
    func testDisplayRepresentationLeadsWithTheCollectionAndNamesTheContainers() throws {
        let entity = ScheduledCollectionEntity(
            occurrence: try Self.occurrence(
                day: 21,
                containers: [
                    ContainerKind(sourceID: "general", sourceLabel: "Black wheelie bin"),
                    ContainerKind(sourceID: "green", sourceLabel: "Green recycling box"),
                ]
            ),
            propertyName: "Home",
            isPutOut: false
        )

        XCTAssertEqual(
            String(localized: entity.displayRepresentation.title),
            "Bins + Recycling · Friday, 21 August 2026"
        )
        XCTAssertEqual(
            entity.displayRepresentation.subtitle.map { String(localized: $0) },
            "Home — put out Black wheelie bin and Green recycling box"
        )
        XCTAssertEqual(entity.summary, "Bins + Recycling")
        XCTAssertEqual(entity.containers, ["Black wheelie bin", "Green recycling box"])
        XCTAssertFalse(entity.isPutOut)
    }

    func testAPutOutCollectionSaysSoInTheSubtitle() throws {
        let entity = ScheduledCollectionEntity(
            occurrence: try Self.occurrence(
                day: 21,
                containers: [ContainerKind(sourceID: "garden", sourceLabel: "Garden waste bin")]
            ),
            propertyName: "Home",
            isPutOut: true
        )

        XCTAssertEqual(
            entity.displayRepresentation.subtitle.map { String(localized: $0) },
            "Home — already put out: Garden waste bin"
        )
    }

    /// Midday survives a conversion to UTC; midnight does not.
    func testExposedDatesUseEuropeLondonMiddayAndThePreviousEvening() throws {
        let entity = ScheduledCollectionEntity(
            occurrence: try Self.occurrence(
                day: 29,
                month: 3,
                containers: [ContainerKind(sourceID: "garden", sourceLabel: "Garden waste bin")]
            ),
            propertyName: "Home",
            isPutOut: false
        )

        XCTAssertEqual(LocalDate(date: entity.collectionDate), try LocalDate(year: 2026, month: 3, day: 29))
        XCTAssertEqual(LocalDate(date: entity.putOutDate), try LocalDate(year: 2026, month: 3, day: 28))
        XCTAssertEqual(
            entity.putOutDate,
            try LocalDate(year: 2026, month: 3, day: 28).date(hour: 18)
        )
    }

    func testIdentifierIsTheOccurrenceIDAndHoldsNoUPRN() throws {
        let occurrence = try Self.occurrence(
            day: 21,
            containers: [ContainerKind(sourceID: "general", sourceLabel: "Black wheelie bin")]
        )
        let entity = ScheduledCollectionEntity(
            occurrence: occurrence,
            propertyName: "Home",
            isPutOut: false
        )

        XCTAssertEqual(entity.id, occurrence.id)
        XCTAssertFalse(entity.id.contains(Self.uprn))
    }

    private static let uprn = "123456789"

    private static let propertyID = UUID(uuidString: "E1717000-0000-4000-8000-000000000001")!

    private static func occurrence(
        day: Int,
        month: Int = 8,
        containers: [ContainerKind]
    ) throws -> CollectionOccurrence {
        CollectionOccurrence(
            propertyID: propertyID,
            localDate: try LocalDate(year: 2026, month: month, day: day),
            containers: containers
        )
    }
}
