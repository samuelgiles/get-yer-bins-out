import XCTest
@testable import BinsOut

final class CollectionAnswerServiceTests: XCTestCase {
    func testFreshSavedScheduleAnswersForTheConfiguredPropertyWithoutContactingTheCouncil() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let provider = CountingCollectionProvider(snapshot: nil)
        let service = Self.service(
            store: TestAppDataStore(data: try Self.persisted(fetchedAt: now.addingTimeInterval(-3_600))),
            provider: provider,
            now: now
        )

        let context = await service.context()
        let answer = CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: context)

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(context.propertyDisplayName, "Home")
        XCTAssertEqual(
            answer.fullText,
            "The next scheduled collection for Home is Bins + Recycling on Friday, 21 August 2026. Put out Black wheelie bin and Green recycling box. Then garden waste on Saturday, 29 August 2026."
        )
        // Spoken while the snippet is visible, so it must stand alone.
        XCTAssertEqual(
            answer.supportingText,
            "Bins + Recycling tomorrow, then garden waste on Saturday."
        )
        XCTAssertEqual(answer.systemImageName, "trash.fill")
    }

    func testStaleSavedScheduleIsRefreshedPersistedAndRepublishedToTheWidget() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let store = TestAppDataStore(
            data: try Self.persisted(fetchedAt: now.addingTimeInterval(-13 * 60 * 60))
        )
        let refreshed = try Self.snapshot(
            fetchedAt: now,
            containers: [
                ProviderContainerSchedule(
                    sourceID: "garden",
                    sourceLabel: "Garden waste bin",
                    dates: [try LocalDate(year: 2026, month: 8, day: 22)]
                ),
            ]
        )
        let provider = CountingCollectionProvider(snapshot: refreshed)
        let payloadStore = TestWidgetPayloadStore()
        let reloader = CountingWidgetTimelineReloader()
        let service = Self.service(
            store: store,
            provider: provider,
            widgetPayloadStore: payloadStore,
            widgetTimelineReloader: reloader,
            now: now
        )

        let context = await service.context()

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 1)
        XCTAssertEqual(context.nextOccurrence?.localDate, try LocalDate(year: 2026, month: 8, day: 22))
        XCTAssertFalse(context.isStale)

        let persisted = try await store.load()
        XCTAssertEqual(persisted?.snapshot?.fetchedAt, now)
        XCTAssertEqual(persisted?.property.displayName, "Home")

        let payload = try await payloadStore.load()
        XCTAssertEqual(payload.propertyDisplayName, "Home")
        XCTAssertEqual(payload.occurrences.first?.localDate, WidgetLocalDate(year: 2026, month: 8, day: 22))
        let reloadCount = await reloader.callCount
        XCTAssertEqual(reloadCount, 1)
    }

    func testMissingSnapshotAndExhaustedScheduleBothTriggerARefresh() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let refreshed = try Self.snapshot(fetchedAt: now)

        let withoutSnapshot = CountingCollectionProvider(snapshot: refreshed)
        _ = await Self.service(
            store: TestAppDataStore(data: try Self.persisted(snapshot: nil)),
            provider: withoutSnapshot,
            now: now
        ).context()
        let withoutSnapshotCalls = await withoutSnapshot.callCount
        XCTAssertEqual(withoutSnapshotCalls, 1)

        // Fetched moments ago, but every saved date is in the past.
        let exhausted = CountingCollectionProvider(snapshot: refreshed)
        _ = await Self.service(
            store: TestAppDataStore(
                data: try Self.persisted(
                    fetchedAt: now,
                    containers: [
                        ProviderContainerSchedule(
                            sourceID: "general",
                            sourceLabel: "Black wheelie bin",
                            dates: [try LocalDate(year: 2026, month: 8, day: 1)]
                        ),
                    ]
                )
            ),
            provider: exhausted,
            now: now
        ).context()
        let exhaustedCalls = await exhausted.callCount
        XCTAssertEqual(exhaustedCalls, 1)
    }

    func testRefreshFailureKeepsTheLastGoodScheduleAndSaysItMayBeOutOfDate() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let store = TestAppDataStore(
            data: try Self.persisted(fetchedAt: now.addingTimeInterval(-13 * 60 * 60))
        )
        let service = Self.service(store: store, provider: FailingCollectionProvider(), now: now)

        let context = await service.context()
        let answer = CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: context)

        XCTAssertEqual(context.nextOccurrence?.localDate, try LocalDate(year: 2026, month: 8, day: 21))
        XCTAssertTrue(context.isStale)
        XCTAssertTrue(answer.fullText.hasSuffix("The saved schedule may be out of date."))
        XCTAssertTrue(answer.supportingText.hasSuffix("This may be out of date."))

        let persisted = try await store.load()
        XCTAssertEqual(persisted?.snapshot?.occurrences.count, 2)
        XCTAssertNotNil(persisted?.snapshot?.lastRefreshError)
    }

    func testRecentFailureIsNotRetriedOnEveryQuestion() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let store = TestAppDataStore(
            data: try Self.persisted(fetchedAt: now.addingTimeInterval(-13 * 60 * 60))
        )
        let provider = FailingCollectionProvider()
        let service = Self.service(store: store, provider: provider, now: now)

        _ = await service.context()
        let afterFirst = await provider.callCount
        XCTAssertEqual(afterFirst, 1)

        // A second question a minute later answers from cache instead of retrying.
        let soonAfter = Self.service(
            store: store,
            provider: provider,
            now: now.addingTimeInterval(60)
        )
        _ = await soonAfter.context()
        let afterSecond = await provider.callCount
        XCTAssertEqual(afterSecond, 1)

        // Forcing a refresh does not override the back-off either.
        _ = await soonAfter.context(refresh: .force)
        let afterForced = await provider.callCount
        XCTAssertEqual(afterForced, 1)

        // Past the back-off window it tries again.
        let later = Self.service(
            store: store,
            provider: provider,
            now: now.addingTimeInterval(16 * 60)
        )
        _ = await later.context()
        let afterBackoff = await provider.callCount
        XCTAssertEqual(afterBackoff, 2)
    }

    func testNeverModeDoesNotContactTheCouncilEvenWithNothingSaved() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let provider = CountingCollectionProvider(snapshot: nil)
        let service = Self.service(
            store: TestAppDataStore(data: try Self.persisted(snapshot: nil)),
            provider: provider,
            now: now
        )

        let context = await service.context(refresh: .never)

        let callCount = await provider.callCount
        XCTAssertEqual(callCount, 0)
        XCTAssertEqual(context.propertyDisplayName, "Home")
        XCTAssertNil(context.nextOccurrence)
    }

    func testPutOutTimeUsesThePreviousLondonEveningAcrossTheBSTBoundary() async throws {
        let now = Self.date(year: 2026, month: 3, day: 27, hour: 18)
        let service = Self.service(
            store: TestAppDataStore(
                data: try Self.persisted(
                    fetchedAt: now,
                    containers: [
                        ProviderContainerSchedule(
                            sourceID: "garden",
                            sourceLabel: "Garden waste",
                            dates: [try LocalDate(year: 2026, month: 3, day: 29)]
                        ),
                    ]
                )
            ),
            provider: CountingCollectionProvider(snapshot: nil),
            now: now
        )

        let answer = CollectionAnswerPhrasing.answer(
            to: .putOutTime,
            context: await service.context()
        )

        XCTAssertEqual(
            answer.fullText,
            "Put out Garden waste on the evening of Saturday, 28 March 2026 for Home’s scheduled Sunday, 29 March 2026 collection."
        )
        XCTAssertEqual(answer.supportingText, "Put them out on Saturday evening.")
    }

    func testTodayCollectionExplainsThatThePutOutEveningHasPassed() async throws {
        let now = Self.date(year: 2026, month: 8, day: 21, hour: 8)
        let service = Self.service(
            store: TestAppDataStore(
                data: try Self.persisted(
                    fetchedAt: now,
                    containers: [
                        ProviderContainerSchedule(
                            sourceID: "food",
                            sourceLabel: "Food waste bin",
                            dates: [try LocalDate(year: 2026, month: 8, day: 21)]
                        ),
                    ]
                )
            ),
            provider: CountingCollectionProvider(snapshot: nil),
            now: now
        )

        let answer = CollectionAnswerPhrasing.answer(
            to: .putOutTime,
            context: await service.context()
        )

        XCTAssertEqual(
            answer.fullText,
            "Today’s scheduled Food waste collection for Home was due out yesterday evening. Put out Food waste bin."
        )
        XCTAssertEqual(answer.supportingText, "They were due out yesterday evening.")
    }

    func testAlreadyPutOutCollectionIsReportedRatherThanRepeated() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let persisted = try Self.persisted(fetchedAt: now)
        let nextID = try XCTUnwrap(persisted.snapshot?.occurrences.first?.id)
        var completionState = CompletionState()
        completionState.markPutOut(nextID, at: now)

        let service = Self.service(
            store: TestAppDataStore(data: persisted),
            completionStore: TestCompletionStore(state: completionState),
            provider: CountingCollectionProvider(snapshot: nil),
            now: now
        )
        let context = await service.context()

        XCTAssertTrue(context.isNextPutOut)
        let next = CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: context)
        XCTAssertTrue(next.fullText.hasSuffix("You’ve already marked these as put out."))
        XCTAssertTrue(next.supportingText.hasPrefix("Already put out."))
        XCTAssertEqual(
            CollectionAnswerPhrasing.answer(to: .putOutTime, context: context).fullText,
            "You’ve already marked Home’s Friday, 21 August 2026 collection as put out."
        )
        XCTAssertEqual(
            CollectionAnswerPhrasing.answer(to: .putOutTime, context: context).supportingText,
            "Already put out."
        )
    }

    func testUnreadableStoreAndUnconfiguredAppAreDistinctAndInventNoSchedule() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)

        let unreadable = await Self.service(
            store: FailingAppDataStore(),
            provider: CountingCollectionProvider(snapshot: nil),
            now: now
        ).context()
        XCTAssertEqual(unreadable.state, .unavailable)
        XCTAssertEqual(
            CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: unreadable).fullText,
            "I can’t read the saved collection schedule right now."
        )

        let unconfigured = await Self.service(
            store: TestAppDataStore(data: nil),
            provider: CountingCollectionProvider(snapshot: nil),
            now: now
        ).context()
        XCTAssertEqual(unconfigured.state, .notConfigured)
        XCTAssertEqual(
            CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: unconfigured).fullText,
            "Set up a property in Bins Out first. Then I can answer questions about its scheduled collections."
        )
        XCTAssertEqual(
            CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: unconfigured).supportingText,
            "Add a property in Bins Out first."
        )
    }

    func testExhaustedScheduleThatCannotBeRefreshedSaysSoForTheNamedProperty() async throws {
        let now = Self.date(year: 2026, month: 8, day: 20, hour: 10)
        let service = Self.service(
            store: TestAppDataStore(
                data: try Self.persisted(
                    fetchedAt: now,
                    containers: [
                        ProviderContainerSchedule(
                            sourceID: "general",
                            sourceLabel: "Black wheelie bin",
                            dates: [try LocalDate(year: 2026, month: 8, day: 1)]
                        ),
                    ]
                )
            ),
            provider: FailingCollectionProvider(),
            now: now
        )

        let answer = CollectionAnswerPhrasing.answer(
            to: .nextScheduledCollection,
            context: await service.context()
        )

        XCTAssertEqual(
            answer.fullText,
            "There are no upcoming scheduled collections saved for Home. Open Bins Out to refresh the schedule."
        )
        XCTAssertEqual(answer.supportingText, "No upcoming dates saved for Home.")
    }

    func testGlassBottleAnswerMatchesOfficialBristolGuidance() {
        let answer = CollectionAnswerPhrasing.answer(
            to: .glassBottleSorting,
            context: CollectionAnswerContext(
                state: .notConfigured,
                today: LocalDate(date: Self.date(year: 2026, month: 8, day: 20, hour: 10))
            )
        )

        XCTAssertEqual(
            answer.fullText,
            "In Bristol, rinse glass bottles and jars and put them in the black recycling box. Put their lids in the green recycling box. This does not apply to broken glass, window glass, drinking glass, or Pyrex."
        )
        XCTAssertEqual(
            answer.supportingText,
            "Bottles and jars in the black box, lids in the green box."
        )
        XCTAssertEqual(
            CollectionAnswerPhrasing.officialGlassBottleGuidanceURL,
            BristolOfficialLinks.blackRecyclingBox
        )
    }

    // MARK: - Fixtures

    static let property = Property(
        id: UUID(uuidString: "51710000-0000-4000-8000-000000000001")!,
        council: .bristolCityCouncil,
        uprn: "123456789",
        displayName: "Home"
    )

    static let defaultContainers: [ProviderContainerSchedule] = {
        guard let collection = try? LocalDate(year: 2026, month: 8, day: 21),
              let garden = try? LocalDate(year: 2026, month: 8, day: 29) else {
            preconditionFailure("Fixture dates must be valid")
        }
        return [
            ProviderContainerSchedule(sourceID: "general", sourceLabel: "Black wheelie bin", dates: [collection]),
            ProviderContainerSchedule(sourceID: "green", sourceLabel: "Green recycling box", dates: [collection]),
            ProviderContainerSchedule(sourceID: "garden", sourceLabel: "Garden waste bin", dates: [garden]),
        ]
    }()

    static func snapshot(
        fetchedAt: Date,
        containers: [ProviderContainerSchedule]? = nil
    ) throws -> ScheduleSnapshot {
        ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "test",
            providerDisplayName: "Test provider",
            fetchedAt: fetchedAt,
            containers: containers ?? defaultContainers
        )
    }

    static func persisted(
        fetchedAt: Date = Date(timeIntervalSince1970: 0),
        containers: [ProviderContainerSchedule]? = nil
    ) throws -> PersistedAppData {
        PersistedAppData(
            property: property,
            snapshot: try snapshot(fetchedAt: fetchedAt, containers: containers)
        )
    }

    static func persisted(snapshot: ScheduleSnapshot?) throws -> PersistedAppData {
        PersistedAppData(property: property, snapshot: snapshot)
    }

    static func service(
        store: any AppDataStoring,
        completionStore: any CompletionStoring = TestCompletionStore(state: CompletionState()),
        provider: any CollectionProvider,
        widgetPayloadStore: any WidgetPayloadStoring = TestWidgetPayloadStore(),
        widgetTimelineReloader: any WidgetTimelineReloading = NoopWidgetTimelineReloader(),
        now: Date
    ) -> CollectionAnswerService {
        CollectionAnswerService(
            store: store,
            completionStore: completionStore,
            provider: provider,
            widgetPayloadStore: widgetPayloadStore,
            widgetTimelineReloader: widgetTimelineReloader,
            now: { now }
        )
    }

    static func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        guard let localDate = try? LocalDate(year: year, month: month, day: day) else {
            preconditionFailure("Fixture date must be valid")
        }
        return localDate.date(hour: hour)
    }
}

private actor CountingCollectionProvider: CollectionProvider {
    nonisolated let identifier = "counting"
    nonisolated let displayName = "Counting provider"

    private let snapshot: ScheduleSnapshot?
    private(set) var callCount = 0

    init(snapshot: ScheduleSnapshot?) {
        self.snapshot = snapshot
    }

    func schedule(for property: Property) async throws -> ScheduleSnapshot {
        callCount += 1
        guard let snapshot else { throw CollectionProviderError.noCollections }
        return snapshot
    }
}

private actor FailingCollectionProvider: CollectionProvider {
    nonisolated let identifier = "failing"
    nonisolated let displayName = "Failing provider"

    private(set) var callCount = 0

    func schedule(for property: Property) async throws -> ScheduleSnapshot {
        callCount += 1
        throw URLError(.notConnectedToInternet)
    }
}

private actor TestAppDataStore: AppDataStoring {
    private var data: PersistedAppData?

    init(data: PersistedAppData?) {
        self.data = data
    }

    func load() async throws -> PersistedAppData? {
        data
    }

    func save(_ data: PersistedAppData) async throws {
        self.data = data
    }
}

private struct FailingAppDataStore: AppDataStoring {
    enum Failure: Error {
        case unreadable
    }

    func load() async throws -> PersistedAppData? {
        throw Failure.unreadable
    }

    func save(_ data: PersistedAppData) async throws { }
}

private actor TestCompletionStore: CompletionStoring {
    private var state: CompletionState

    init(state: CompletionState) {
        self.state = state
    }

    func load() async throws -> CompletionState {
        state
    }

    func save(_ state: CompletionState) async throws {
        self.state = state
    }
}

private actor TestWidgetPayloadStore: WidgetPayloadStoring {
    private var payload = WidgetSchedulePayload.empty

    func load() async throws -> WidgetSchedulePayload {
        payload
    }

    func save(_ payload: WidgetSchedulePayload) async throws {
        self.payload = payload
    }
}

private actor CountingWidgetTimelineReloader: WidgetTimelineReloading {
    private(set) var callCount = 0

    func reloadCollectionWidget() async {
        callCount += 1
    }
}
