import XCTest
@testable import BinsOut

final class SiriCollectionAnswerServiceTests: XCTestCase {
    func testNextScheduledCollectionProvidesExactScheduledAnswer() {
        let answer = SiriCollectionAnswerService.answer(
            to: .nextScheduledCollection,
            payload: payload(
                occurrences: [
                    occurrence(
                        id: "collection-1",
                        date: WidgetLocalDate(year: 2026, month: 8, day: 21),
                        containers: [
                            WidgetContainer(id: "general", name: "Black wheelie bin", symbolName: "trash.fill"),
                            WidgetContainer(id: "green", name: "Green recycling box", symbolName: "arrow.3.trianglepath"),
                        ]
                    ),
                ]
            ),
            at: date(year: 2026, month: 8, day: 20, hour: 10)
        )

        XCTAssertEqual(
            answer.spokenText,
            "The next scheduled collection for Home is Bins + Recycling on Friday, 21 August 2026. Put out Black wheelie bin and Green recycling box."
        )
        XCTAssertEqual(
            answer.supportingText,
            "Collection dates are scheduled dates, not confirmation that a crew completed collection."
        )
        XCTAssertEqual(answer.systemImageName, "trash.fill")
    }

    func testPutOutTimeUsesPreviousLondonEveningAcrossBSTStart() {
        let answer = SiriCollectionAnswerService.answer(
            to: .putOutTime,
            payload: payload(
                occurrences: [
                    occurrence(
                        id: "garden-1",
                        date: WidgetLocalDate(year: 2026, month: 3, day: 29),
                        containers: [
                            WidgetContainer(id: "garden", name: "Garden waste", symbolName: "leaf.fill"),
                        ]
                    ),
                ]
            ),
            at: date(year: 2026, month: 3, day: 27, hour: 18)
        )

        XCTAssertEqual(
            answer.spokenText,
            "Put out Garden waste on the evening of Saturday, 28 March 2026 for Home’s scheduled Sunday, 29 March 2026 collection."
        )
        XCTAssertEqual(answer.supportingText, "The saved schedule uses Europe/London collection dates.")
    }

    func testTodayCollectionExplainsThatThePutOutEveningHasPassed() {
        let answer = SiriCollectionAnswerService.answer(
            to: .putOutTime,
            payload: payload(
                occurrences: [
                    occurrence(
                        id: "food-1",
                        date: WidgetLocalDate(year: 2026, month: 8, day: 21),
                        containers: [
                            WidgetContainer(id: "food", name: "Food waste bin", symbolName: "fork.knife"),
                        ]
                    ),
                ]
            ),
            at: date(year: 2026, month: 8, day: 21, hour: 8)
        )

        XCTAssertEqual(
            answer.spokenText,
            "Today’s scheduled Food waste collection for Home was due out yesterday evening. Put out Food waste bin."
        )
        XCTAssertEqual(answer.supportingText, "The collection date is Friday, 21 August 2026.")
    }

    func testStaleScheduleAndUnknownContainerRemainExplicit() {
        let answer = SiriCollectionAnswerService.answer(
            to: .nextScheduledCollection,
            payload: WidgetSchedulePayload(
                propertyDisplayName: "Home",
                occurrences: [
                    occurrence(
                        id: "other-1",
                        date: WidgetLocalDate(year: 2026, month: 8, day: 21),
                        containers: [
                            WidgetContainer(id: "other", name: "Other council container", symbolName: "shippingbox"),
                        ]
                    ),
                ],
                fetchedAt: date(year: 2026, month: 8, day: 20, hour: 9),
                hasRefreshIssue: true
            ),
            at: date(year: 2026, month: 8, day: 20, hour: 10)
        )

        XCTAssertEqual(
            answer.spokenText,
            "The next scheduled collection for Home is Other council container on Friday, 21 August 2026. Put out Other council container. The saved schedule may be out of date."
        )
    }

    func testNoPropertyAndEmptyScheduleHaveFocusedRecoveryAnswers() {
        let now = date(year: 2026, month: 8, day: 20, hour: 10)

        XCTAssertEqual(
            SiriCollectionAnswerService.answer(
                to: .nextScheduledCollection,
                payload: .empty,
                at: now
            ).spokenText,
            "Set up a property in Bins Out first."
        )

        XCTAssertEqual(
            SiriCollectionAnswerService.answer(
                to: .nextScheduledCollection,
                payload: payload(occurrences: []),
                at: now
            ).spokenText,
            "There are no upcoming scheduled collections saved for Home."
        )
    }

    func testGlassBottleAnswerMatchesOfficialBristolGuidance() {
        let answer = SiriCollectionAnswerService.answer(
            to: .glassBottleSorting,
            payload: .empty,
            at: date(year: 2026, month: 8, day: 20, hour: 10)
        )

        XCTAssertEqual(
            answer.spokenText,
            "In Bristol, rinse glass bottles and jars and put them in the black recycling box. Put their lids in the green recycling box."
        )
        XCTAssertEqual(
            answer.supportingText,
            "This does not apply to broken glass, window glass, drinking glass, or Pyrex. Check Bristol’s official guidance."
        )
        XCTAssertEqual(
            SiriCollectionAnswerService.officialGlassBottleGuidanceURL,
            BristolOfficialLinks.blackRecyclingBox
        )
    }

    func testInjectedStoreFailureDoesNotInventASchedule() async {
        let fixedNow = date(year: 2026, month: 8, day: 20, hour: 10)
        let service = SiriCollectionAnswerService(
            payloadStore: FailingPayloadStore(),
            now: { fixedNow }
        )

        let answer = await service.answer(to: .nextScheduledCollection)

        XCTAssertEqual(answer.spokenText, "I can’t read the saved collection schedule right now.")
        XCTAssertEqual(answer.supportingText, "Open Bins Out to refresh the saved schedule.")
    }

    private func payload(occurrences: [WidgetCollectionOccurrence]) -> WidgetSchedulePayload {
        WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: occurrences,
            fetchedAt: date(year: 2026, month: 8, day: 20, hour: 9),
            hasRefreshIssue: false
        )
    }

    private func occurrence(
        id: String,
        date: WidgetLocalDate,
        containers: [WidgetContainer]
    ) -> WidgetCollectionOccurrence {
        WidgetCollectionOccurrence(id: id, localDate: date, containers: containers)
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        WidgetLocalDate(year: year, month: month, day: day).dateAtNoon
            .addingTimeInterval(TimeInterval(hour - 12) * 60 * 60)
    }
}

private struct FailingPayloadStore: WidgetPayloadStoring {
    enum Failure: Error {
        case unavailable
    }

    func load() async throws -> WidgetSchedulePayload {
        throw Failure.unavailable
    }

    func save(_ payload: WidgetSchedulePayload) async throws { }
}
