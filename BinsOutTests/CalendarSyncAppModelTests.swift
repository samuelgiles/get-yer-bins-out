import XCTest
@testable import BinsOut

@MainActor
final class CalendarSyncAppModelTests: XCTestCase {
    func testSelectingCalendarImmediatelyAppliesAReconciliation() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = testProperty()
        let snapshot = try await FixtureCollectionProvider(now: { now }).schedule(for: property)
        let service = RecordingCalendarService()
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: CalendarTestStore(data: PersistedAppData(property: property, snapshot: snapshot)),
            calendarService: service,
            now: { now }
        )

        await model.load()
        await model.selectCalendar(SelectedCalendar(identifier: "calendar", title: "Home"))

        XCTAssertEqual(service.appliedPlanCount, 1)
        XCTAssertEqual(model.settings.calendar.selectedCalendarIdentifier, "calendar")
        XCTAssertEqual(model.settings.calendar.lastReconciledAt, now)
    }

    func testSuccessfulRefreshAutomaticallyAppliesCalendarReconciliation() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = testProperty()
        let initialSnapshot = try await FixtureCollectionProvider(now: { now.addingTimeInterval(-3_600) }).schedule(for: property)
        var settings = UserSettings()
        settings.calendar.isEnabled = true
        settings.calendar.selectedCalendarIdentifier = "calendar"
        settings.calendar.selectedCalendarTitle = "Home"
        let service = RecordingCalendarService()
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: CalendarTestStore(
                data: PersistedAppData(property: property, snapshot: initialSnapshot, settings: settings)
            ),
            calendarService: service,
            now: { now }
        )

        await model.load()
        service.reset()
        await model.refresh()

        XCTAssertEqual(service.preparedPlanCount, 1)
        XCTAssertEqual(service.appliedPlanCount, 1)
        XCTAssertEqual(model.settings.calendar.lastReconciledAt, now)
    }

    func testCalendarStoreChangeAutomaticallyReconcilesWhenEnabled() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = testProperty()
        let snapshot = try await FixtureCollectionProvider(now: { now }).schedule(for: property)
        var settings = UserSettings()
        settings.calendar.isEnabled = true
        settings.calendar.selectedCalendarIdentifier = "calendar"
        let service = RecordingCalendarService()
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: CalendarTestStore(
                data: PersistedAppData(property: property, snapshot: snapshot, settings: settings)
            ),
            calendarService: service,
            now: { now }
        )

        await model.load()
        service.reset()
        await model.calendarStoreChanged()

        XCTAssertEqual(service.preparedPlanCount, 1)
        XCTAssertEqual(service.appliedPlanCount, 1)
    }

    func testRevokedPermissionDoesNotAttemptCalendarChanges() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = testProperty()
        let snapshot = try await FixtureCollectionProvider(now: { now }).schedule(for: property)
        var settings = UserSettings()
        settings.calendar.isEnabled = true
        settings.calendar.selectedCalendarIdentifier = "calendar"
        let service = RecordingCalendarService(permission: .denied)
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: CalendarTestStore(
                data: PersistedAppData(property: property, snapshot: snapshot, settings: settings)
            ),
            calendarService: service,
            now: { now }
        )

        await model.load()

        XCTAssertEqual(service.preparedPlanCount, 0)
        XCTAssertEqual(service.appliedPlanCount, 0)
        XCTAssertEqual(model.calendarPermission, .denied)
        XCTAssertTrue(model.settings.calendar.isEnabled)
    }

    func testUnavailableCalendarDoesNotApplyChangesAndKeepsSelectionForReplacement() async throws {
        let now = Date(timeIntervalSince1970: 1_786_867_200)
        let property = testProperty()
        let snapshot = try await FixtureCollectionProvider(now: { now }).schedule(for: property)
        let service = RecordingCalendarService(prepareError: .calendarUnavailable)
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: CalendarTestStore(data: PersistedAppData(property: property, snapshot: snapshot)),
            calendarService: service,
            now: { now }
        )

        await model.load()
        await model.selectCalendar(SelectedCalendar(identifier: "removed-calendar", title: "Removed"))

        XCTAssertEqual(service.preparedPlanCount, 1)
        XCTAssertEqual(service.appliedPlanCount, 0)
        XCTAssertEqual(model.settings.calendar.selectedCalendarIdentifier, "removed-calendar")
        XCTAssertEqual(model.integrationMessage, CalendarSyncError.calendarUnavailable.errorDescription)
    }

    private func testProperty() -> Property {
        Property(
            id: UUID(uuidString: "C4110000-0000-4000-8000-000000000001")!,
            council: .bristolCityCouncil,
            uprn: "001234567890",
            displayName: "Test home"
        )
    }
}

@MainActor
private final class RecordingCalendarService: CalendarSyncServicing {
    var permission: CalendarPermissionStatus
    var prepareError: CalendarSyncError?
    var preparedPlanCount = 0
    var appliedPlanCount = 0

    init(permission: CalendarPermissionStatus = .allowed, prepareError: CalendarSyncError? = nil) {
        self.permission = permission
        self.prepareError = prepareError
    }

    func permissionStatus() -> CalendarPermissionStatus { permission }
    func requestFullAccess() async throws -> Bool { true }

    func preparePlan(
        snapshot: ScheduleSnapshot,
        state: CalendarSyncState,
        currentDate: LocalDate
    ) throws -> CalendarReconciliationPlan {
        preparedPlanCount += 1
        if let prepareError { throw prepareError }
        guard let calendarIdentifier = state.selectedCalendarIdentifier else {
            throw CalendarSyncError.calendarUnavailable
        }
        return CalendarReconciliationPlan(
            calendarIdentifier: calendarIdentifier,
            actions: [],
            recoveredReferences: [:],
            newlySuppressedOccurrenceIDs: []
        )
    }

    func apply(
        plan: CalendarReconciliationPlan,
        to state: CalendarSyncState,
        at date: Date
    ) throws -> CalendarSyncState {
        appliedPlanCount += 1
        var state = state
        state.lastReconciledAt = date
        return state
    }

    func removeFutureManagedEvents(
        from state: CalendarSyncState,
        currentDate: LocalDate,
        at date: Date
    ) throws -> CalendarSyncState {
        var state = state
        state.isEnabled = false
        state.lastReconciledAt = date
        return state
    }

    func reset() {
        preparedPlanCount = 0
        appliedPlanCount = 0
    }
}

private actor CalendarTestStore: AppDataStoring {
    private var data: PersistedAppData?

    init(data: PersistedAppData?) {
        self.data = data
    }

    func load() async throws -> PersistedAppData? { data }

    func save(_ data: PersistedAppData) async throws {
        self.data = data
    }
}
