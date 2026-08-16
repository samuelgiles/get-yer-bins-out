import XCTest
@testable import BinsOut

@MainActor
final class AppEnvironmentTests: XCTestCase {
    func testLiveBristolProviderIsTheDefault() {
        let model = AppEnvironment.makeAppModel(environment: [:])

        XCTAssertEqual(model.activeProviderIdentifier, "bristol-next-collection-dates")
        XCTAssertFalse(model.isUsingFixtureProvider)
    }

    func testFixtureProviderRemainsExplicitlyAvailable() {
        let model = AppEnvironment.makeAppModel(environment: ["BINS_OUT_USE_FIXTURE": "1"])

        XCTAssertEqual(model.activeProviderIdentifier, "fixture")
        XCTAssertTrue(model.isUsingFixtureProvider)
    }
}
