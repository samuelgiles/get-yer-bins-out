import XCTest
@testable import BinsOut

@MainActor
final class LiveActivityPreviewTests: XCTestCase {
    func testSettingsPreviewToggleStartsAndStopsAnIsolatedPreview() async throws {
        let now = try LocalDate(year: 2026, month: 8, day: 20).date(hour: 12)
        let collectionDate = try LocalDate(year: 2026, month: 8, day: 21)
        let property = Property(
            id: try XCTUnwrap(UUID(uuidString: "A1710170-0000-4000-8000-000000000002")),
            council: .bristolCityCouncil,
            uprn: "001234567890",
            displayName: "Test property"
        )
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "fixture",
            providerDisplayName: "Fixture",
            fetchedAt: now,
            containers: [
                ProviderContainerSchedule(
                    sourceID: "food",
                    sourceLabel: "Food waste bin",
                    dates: [collectionDate]
                ),
            ]
        )
        let service = RecordingLiveActivityService()
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { now }),
            store: PreviewAppDataStore(),
            liveActivityService: service,
            now: { now }
        )
        model.prepareForPreview(property: property, snapshot: snapshot)

        await model.setLiveActivityPreviewEnabled(true)

        XCTAssertTrue(model.isLiveActivityPreviewActive)
        let requestedSegment = await service.requestedSegment()
        XCTAssertEqual(requestedSegment?.id, SystemIdentifiers.liveActivityPreviewScheduleID)
        XCTAssertEqual(
            requestedSegment?.occurrenceID,
            SystemIdentifiers.liveActivityPreviewOccurrenceID
        )

        await model.setLiveActivityPreviewEnabled(false)

        XCTAssertFalse(model.isLiveActivityPreviewActive)
        let stopCallCount = await service.stopCallCount()
        XCTAssertEqual(stopCallCount, 1)
    }
}

private actor RecordingLiveActivityService: LiveActivityScheduling {
    private var previewIsActive = false
    private var previewSegment: SharedActivitySegment?
    private var numberOfStopCalls = 0

    func reconcile(
        schedule: SharedActivitySchedule,
        completionState: CompletionState,
        now: Date
    ) async throws -> LiveActivityReconciliationResult {
        schedule.isEnabled ? .scheduled(segmentCount: schedule.segments.count) : .disabled
    }

    func isPreviewActive() async -> Bool {
        previewIsActive
    }

    func startPreview(_ segment: SharedActivitySegment, now: Date) async throws {
        previewSegment = segment
        previewIsActive = true
    }

    func stopPreview() async {
        numberOfStopCalls += 1
        previewIsActive = false
    }

    func requestedSegment() -> SharedActivitySegment? {
        previewSegment
    }

    func stopCallCount() -> Int {
        numberOfStopCalls
    }
}
