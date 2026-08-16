import XCTest
@testable import BinsOut

final class CompletionStateTests: XCTestCase {
    func testMarkingPutOutIsIdempotentAndUndoIsReversible() {
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        var state = CompletionState()

        state.markPutOut("occurrence", at: firstDate)
        state.markPutOut("occurrence", at: secondDate)

        XCTAssertTrue(state.isPutOut("occurrence"))
        XCTAssertEqual(state.records["occurrence"]?.putOutAt, firstDate)

        state.undo("occurrence", at: secondDate)

        XCTAssertFalse(state.isPutOut("occurrence"))
        XCTAssertEqual(state.records["occurrence"]?.undoneAt, secondDate)
    }
}
