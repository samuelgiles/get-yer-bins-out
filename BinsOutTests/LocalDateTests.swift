import XCTest
@testable import BinsOut

final class LocalDateTests: XCTestCase {
    func testParsesProviderTimestampAsLondonDateOnly() throws {
        let localDate = try LocalDate(iso8601Timestamp: "2026-08-21T00:00:00")

        XCTAssertEqual(localDate, try LocalDate(year: 2026, month: 8, day: 21))
        XCTAssertEqual(localDate.rawValue, "2026-08-21")
    }

    func testNoonRepresentationSurvivesBSTStart() throws {
        let transitionDay = try LocalDate(year: 2026, month: 3, day: 29)
        let date = transitionDay.dateAtNoon
        let components = LocalDate.calendar.dateComponents([.year, .month, .day, .hour], from: date)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 29)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(LocalDate.timeZone.secondsFromGMT(for: date), 3_600)
    }

    func testNoonRepresentationSurvivesGMTReturn() throws {
        let transitionDay = try LocalDate(year: 2026, month: 10, day: 25)
        let date = transitionDay.dateAtNoon
        let components = LocalDate.calendar.dateComponents([.year, .month, .day, .hour], from: date)

        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 10)
        XCTAssertEqual(components.day, 25)
        XCTAssertEqual(components.hour, 12)
        XCTAssertEqual(LocalDate.timeZone.secondsFromGMT(for: date), 0)
    }

    func testRejectsMalformedOrImpossibleDates() {
        XCTAssertThrowsError(try LocalDate(iso8601Timestamp: "21/08/2026"))
        XCTAssertThrowsError(try LocalDate(iso8601Timestamp: "2026-02-30T00:00:00"))
    }
}

