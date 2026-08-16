import XCTest
@testable import BinsOut

@MainActor
final class AppModelCacheTests: XCTestCase {
    func testTransientRefreshFailureRetainsAndPersistsLastGoodSnapshot() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = Property(
            id: UUID(uuidString: "CA5E0000-0000-4000-8000-000000000001")!,
            council: .bristolCityCouncil,
            uprn: "123456789",
            displayName: "Home"
        )
        let collectionDate = try LocalDate(year: 2026, month: 8, day: 21)
        let cachedSnapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "live",
            providerDisplayName: "Test provider",
            fetchedAt: now.addingTimeInterval(-3_600),
            containers: [
                ProviderContainerSchedule(sourceID: "food", sourceLabel: "Brown food bin", dates: [collectionDate]),
            ]
        )
        let store = TestAppDataStore(data: PersistedAppData(property: property, snapshot: cachedSnapshot))
        let model = AppModel(
            provider: FailingCollectionProvider(),
            store: store,
            now: { now }
        )

        await model.load()
        await model.refresh()

        XCTAssertEqual(model.snapshot?.occurrences, cachedSnapshot.occurrences)
        XCTAssertEqual(model.snapshot?.fetchedAt, cachedSnapshot.fetchedAt)
        XCTAssertEqual(model.snapshot?.lastRefreshAttemptAt, now)
        XCTAssertNotNil(model.snapshot?.lastRefreshError)

        let persisted = try await store.load()
        XCTAssertEqual(persisted?.snapshot?.occurrences, cachedSnapshot.occurrences)
        XCTAssertEqual(persisted?.snapshot?.fetchedAt, cachedSnapshot.fetchedAt)
        XCTAssertNotNil(persisted?.snapshot?.lastRefreshError)
    }

    func testNewerSyncedPropertyReplacesLocalPropertyAndRefetchesSchedule() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let local = Property(
            id: UUID(uuidString: "CA5E0000-0000-4000-8000-000000000002")!,
            council: .bristolCityCouncil,
            uprn: "111111",
            displayName: "Old home"
        )
        let synced = Property(
            id: UUID(uuidString: "CA5E0000-0000-4000-8000-000000000003")!,
            council: .bristolCityCouncil,
            uprn: "222222",
            displayName: "New home"
        )
        let localUpdatedAt = now.addingTimeInterval(-600)
        let syncedUpdatedAt = now.addingTimeInterval(-60)
        let store = TestAppDataStore(
            data: PersistedAppData(
                property: local,
                snapshot: nil,
                propertyUpdatedAt: localUpdatedAt
            )
        )
        let syncStore = TestPropertySyncStore(
            record: SyncedPropertyRecord(property: synced, updatedAt: syncedUpdatedAt)
        )
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: store,
            propertySyncStore: syncStore,
            now: { now }
        )

        await model.load()

        XCTAssertEqual(model.property, synced)
        XCTAssertEqual(model.snapshot?.propertyID, synced.id)
        let persisted = try await store.load()
        XCTAssertEqual(persisted?.property, synced)
        XCTAssertEqual(persisted?.propertyUpdatedAt, syncedUpdatedAt)
    }

    func testSavingValidatedPropertyPushesItToSyncStore() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = Property(
            id: UUID(uuidString: "CA5E0000-0000-4000-8000-000000000004")!,
            council: .bristolCityCouncil,
            uprn: "333333",
            displayName: "Home"
        )
        let snapshot = try await FixtureCollectionProvider(now: { now }).schedule(for: property)
        let store = TestAppDataStore(data: nil)
        let syncStore = TestPropertySyncStore(record: nil)
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: store,
            propertySyncStore: syncStore,
            now: { now }
        )
        await model.load()

        try await model.save(ValidatedProperty(property: property, snapshot: snapshot))

        let synced = await syncStore.currentRecord()
        XCTAssertEqual(synced, SyncedPropertyRecord(property: property, updatedAt: now))
    }
}

private struct FailingCollectionProvider: CollectionProvider {
    let identifier = "failing"
    let displayName = "Failing provider"

    func schedule(for property: Property) async throws -> ScheduleSnapshot {
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

private actor TestPropertySyncStore: PropertySyncing {
    private var record: SyncedPropertyRecord?

    init(record: SyncedPropertyRecord?) {
        self.record = record
    }

    func load() async throws -> SyncedPropertyRecord? {
        record
    }

    func save(_ record: SyncedPropertyRecord) async throws {
        self.record = record
    }

    func currentRecord() -> SyncedPropertyRecord? {
        record
    }
}
