import XCTest
@testable import BinsOut

final class FileAppDataStoreTests: XCTestCase {
    func testRoundTripsPropertyAndLastGoodSnapshotInInjectedDirectory() async throws {
        let directory = URL.temporaryDirectory
            .appending(path: "BinsOutTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        guard let propertyID = UUID(uuidString: "570AE000-0000-4000-8000-000000000001") else {
            preconditionFailure("Static test UUID must be valid")
        }
        let property = Property(
            id: propertyID,
            council: .bristolCityCouncil,
            uprn: "001234567890",
            displayName: "Home"
        )
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "fixture",
            providerDisplayName: "Sample schedule",
            fetchedAt: Date(timeIntervalSince1970: 1_786_867_200),
            containers: [
                ProviderContainerSchedule(
                    sourceID: "food",
                    sourceLabel: "Brown food bin",
                    dates: [try LocalDate(year: 2026, month: 8, day: 21)]
                ),
            ]
        )
        let expected = PersistedAppData(
            property: property,
            snapshot: snapshot,
            propertyUpdatedAt: Date(timeIntervalSince1970: 1_786_867_100)
        )
        let store = FileAppDataStore(baseDirectory: directory)

        try await store.save(expected)
        let loaded = try await store.load()

        XCTAssertEqual(loaded, expected)
    }
}
