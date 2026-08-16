import XCTest
@testable import BinsOut

final class BristolLiveIntegrationTests: XCTestCase {
    func testAuthorizedPropertyReturnsExpectedContainersAndDates() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["BINS_OUT_RUN_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Live Bristol integration tests are opt-in")
        }
        guard let uprn = environment["BINS_OUT_LIVE_TEST_UPRN"], !uprn.isEmpty else {
            throw XCTSkip("Supply an authorized UPRN outside the repository")
        }

        let property = Property(
            council: .bristolCityCouncil,
            uprn: uprn,
            displayName: "Authorized local smoke test"
        )
        let provider = BristolCollectionProvider(configuration: .officialWebsiteClient)

        let snapshot = try await provider.schedule(for: property)

        let labels = Set(snapshot.occurrences.flatMap(\.containers).map(\.sourceLabel))
        let expectedLabels: Set<String> = [
            "180L General Waste",
            "23L Food Waste Bin",
            "45L Black Recycling Box",
            "55L Green Recycling Box",
            "90L Blue Bag",
        ]
        XCTAssertTrue(expectedLabels.isSubset(of: labels))
        XCTAssertFalse(snapshot.occurrences.isEmpty)
        XCTAssertTrue(snapshot.occurrences.allSatisfy { !$0.containers.isEmpty })
    }
}
