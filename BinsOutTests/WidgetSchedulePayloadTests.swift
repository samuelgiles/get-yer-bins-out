import XCTest
@testable import BinsOut

final class WidgetSchedulePayloadTests: XCTestCase {
    private let property = Property(
        id: UUID(uuidString: "B1D60000-0000-4000-8000-000000000001")!,
        council: .bristolCityCouncil,
        uprn: "001234567890",
        displayName: "Home"
    )

    func testBuilderProvidesGroupedUpcomingCollectionsWithoutUPRN() throws {
        let now = try LocalDate(year: 2026, month: 8, day: 20).date(hour: 9)
        let collectionDate = try LocalDate(year: 2026, month: 8, day: 21)
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "fixture",
            providerDisplayName: "Fixture",
            fetchedAt: now,
            containers: [
                ProviderContainerSchedule(
                    sourceID: "general",
                    sourceLabel: "Black wheelie bin",
                    dates: [collectionDate]
                ),
                ProviderContainerSchedule(
                    sourceID: "green",
                    sourceLabel: "Green recycling box",
                    dates: [collectionDate]
                ),
            ]
        )

        let payload = WidgetSchedulePayloadBuilder.make(
            property: property,
            snapshot: snapshot,
            now: now
        )

        XCTAssertEqual(payload.propertyDisplayName, "Home")
        XCTAssertEqual(payload.occurrences.count, 1)
        XCTAssertEqual(payload.occurrences.first?.localDate, WidgetLocalDate(year: 2026, month: 8, day: 21))
        XCTAssertEqual(payload.occurrences.first?.summary.title, "Bins + Recycling")
        XCTAssertEqual(payload.occurrences.first?.containers.map(\.name).sorted(), ["Black wheelie bin", "Green recycling box"])

        let encoded = try XCTUnwrap(String(data: JSONEncoder().encode(payload), encoding: .utf8))
        XCTAssertFalse(encoded.contains(property.uprn))
        XCTAssertTrue(encoded.contains(property.displayName))
    }

    func testPresentationKeepsLondonDateAtSummerTimeBoundary() {
        let payload = WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: [
                WidgetCollectionOccurrence(
                    id: "first",
                    localDate: WidgetLocalDate(year: 2026, month: 3, day: 29),
                    containers: [WidgetContainer(id: "garden", name: "Garden waste", symbolName: "leaf.fill")]
                ),
            ],
            fetchedAt: Date(timeIntervalSince1970: 1_774_774_800),
            hasRefreshIssue: false
        )
        let beforeBritishSummerTime = Date(timeIntervalSince1970: 1_774_681_200)

        let presentation = payload.presentation(at: beforeBritishSummerTime)

        guard case let .scheduled(propertyName, occurrence, _, isStale) = presentation else {
            return XCTFail("Expected a scheduled presentation")
        }
        XCTAssertEqual(propertyName, "Home")
        XCTAssertEqual(occurrence.localDate, WidgetLocalDate(year: 2026, month: 3, day: 29))
        XCTAssertEqual(occurrence.summary.title, "Garden waste")
        XCTAssertFalse(isStale)
        XCTAssertTrue(occurrence.localDate.fullDescription.contains("29 March 2026"))
    }

    func testPresentationReportsStaleAndEmptyStates() {
        let now = Date(timeIntervalSince1970: 1_786_780_800)
        let stalePayload = WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: [
                WidgetCollectionOccurrence(
                    id: "food",
                    localDate: WidgetLocalDate(date: now),
                    containers: [WidgetContainer(id: "food", name: "Food waste bin", symbolName: "fork.knife")]
                ),
            ],
            fetchedAt: now.addingTimeInterval(-3_600),
            hasRefreshIssue: true
        )

        guard case let .scheduled(_, _, _, isStale) = stalePayload.presentation(at: now) else {
            return XCTFail("Expected a scheduled presentation")
        }
        XCTAssertTrue(isStale)

        let emptyPayload = WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: [],
            fetchedAt: now,
            hasRefreshIssue: false
        )
        XCTAssertEqual(emptyPayload.presentation(at: now), .empty(propertyDisplayName: "Home", fetchedAt: now))
        XCTAssertEqual(WidgetSchedulePayload.empty.presentation(at: now), .notConfigured)
    }

    func testTimelineAdvancesOnTheDayAfterEachKnownCollection() {
        let now = Date(timeIntervalSince1970: 1_786_810_000)
        let payload = WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: [
                WidgetCollectionOccurrence(
                    id: "first",
                    localDate: WidgetLocalDate(year: 2026, month: 8, day: 21),
                    containers: []
                ),
                WidgetCollectionOccurrence(
                    id: "second",
                    localDate: WidgetLocalDate(year: 2026, month: 8, day: 28),
                    containers: []
                ),
            ],
            fetchedAt: now,
            hasRefreshIssue: false
        )

        let dates = payload.timelineDates(startingAt: now)

        XCTAssertEqual(dates.count, 3)
        XCTAssertEqual(WidgetLocalDate(date: dates[1]), WidgetLocalDate(year: 2026, month: 8, day: 22))
        XCTAssertEqual(WidgetLocalDate(date: dates[2]), WidgetLocalDate(year: 2026, month: 8, day: 29))
        XCTAssertGreaterThan(payload.suggestedReloadDate(after: now), dates[2])
    }

    func testFileStoreRoundTripsInInjectedDirectory() async throws {
        let directory = URL.temporaryDirectory
            .appending(path: "BinsOutWidgetTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: [],
            fetchedAt: Date(timeIntervalSince1970: 1_786_867_200),
            hasRefreshIssue: true
        )
        let store = FileWidgetPayloadStore(baseDirectory: directory)

        try await store.save(payload)

        let loaded = try await store.load()
        XCTAssertEqual(loaded, payload)
    }
}

@MainActor
final class WidgetPayloadPublishingTests: XCTestCase {
    func testSavingPropertyPublishesPayloadAndRequestsOneWidgetReload() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let appStore = WidgetTestAppDataStore()
        let widgetStore = WidgetTestPayloadStore()
        let reloader = WidgetTestReloader()
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: appStore,
            widgetPayloadStore: widgetStore,
            widgetTimelineReloader: reloader,
            now: { now }
        )
        await model.load()

        let validated = try await model.validate(
            council: .bristolCityCouncil,
            uprn: "001234567890",
            displayName: "Home"
        )
        try await model.save(validated)

        let payload = await widgetStore.currentPayload()
        XCTAssertEqual(payload.propertyDisplayName, "Home")
        XCTAssertFalse(payload.occurrences.isEmpty)
        let reloadCount = await reloader.reloadCount()
        XCTAssertEqual(reloadCount, 1)
    }
}

private actor WidgetTestAppDataStore: AppDataStoring {
    private var data: PersistedAppData?

    func load() async throws -> PersistedAppData? { data }

    func save(_ data: PersistedAppData) async throws {
        self.data = data
    }
}

private actor WidgetTestPayloadStore: WidgetPayloadStoring {
    private var payload = WidgetSchedulePayload.empty

    func load() async throws -> WidgetSchedulePayload { payload }

    func save(_ payload: WidgetSchedulePayload) async throws {
        self.payload = payload
    }

    func currentPayload() -> WidgetSchedulePayload { payload }
}

private actor WidgetTestReloader: WidgetTimelineReloading {
    private var count = 0

    func reloadCollectionWidget() async {
        count += 1
    }

    func reloadCount() -> Int { count }
}
