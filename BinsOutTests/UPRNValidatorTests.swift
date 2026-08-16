import XCTest
@testable import BinsOut

final class UPRNValidatorTests: XCTestCase {
    func testPreservesLeadingZeroes() throws {
        XCTAssertEqual(try UPRNValidator.validated("001234567890"), "001234567890")
    }

    func testRejectsEmptyValue() {
        XCTAssertThrowsError(try UPRNValidator.validated("")) { error in
            XCTAssertEqual(error as? UPRNValidationError, .empty)
        }
    }

    func testRejectsNonNumericValue() {
        XCTAssertThrowsError(try UPRNValidator.validated("12 34")) { error in
            XCTAssertEqual(error as? UPRNValidationError, .nonNumeric)
        }
        XCTAssertThrowsError(try UPRNValidator.validated("123A")) { error in
            XCTAssertEqual(error as? UPRNValidationError, .nonNumeric)
        }
    }

    func testRejectsMoreThanTwelveDigits() {
        XCTAssertThrowsError(try UPRNValidator.validated("1234567890123")) { error in
            XCTAssertEqual(error as? UPRNValidationError, .tooLong)
        }
    }
}

