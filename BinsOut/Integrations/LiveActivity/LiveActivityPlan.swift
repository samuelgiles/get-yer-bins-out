import Foundation

protocol LiveActivityScheduling: Sendable {
    func reconcile(
        schedule: SharedActivitySchedule,
        completionState: CompletionState,
        now: Date
    ) async throws -> LiveActivityReconciliationResult

    func isPreviewActive() async -> Bool
    func startPreview(_ segment: SharedActivitySegment, now: Date) async throws
    func stopPreview() async
}

struct ActivityKitLiveActivityService: LiveActivityScheduling {
    func reconcile(
        schedule: SharedActivitySchedule,
        completionState: CompletionState,
        now: Date
    ) async throws -> LiveActivityReconciliationResult {
        try await LiveActivityCoordinator().reconcile(
            schedule: schedule,
            completionState: completionState,
            now: now
        )
    }

    func isPreviewActive() async -> Bool {
        LiveActivityCoordinator().isPreviewActive()
    }

    func startPreview(_ segment: SharedActivitySegment, now: Date) async throws {
        try await LiveActivityCoordinator().startPreview(segment, now: now)
    }

    func stopPreview() async {
        await LiveActivityCoordinator().stopPreview()
    }
}

struct NoopLiveActivityService: LiveActivityScheduling {
    func reconcile(
        schedule: SharedActivitySchedule,
        completionState: CompletionState,
        now: Date
    ) async throws -> LiveActivityReconciliationResult {
        schedule.isEnabled ? .unavailable : .disabled
    }

    func isPreviewActive() async -> Bool { false }

    func startPreview(_ segment: SharedActivitySegment, now: Date) async throws {
        throw LiveActivityPreviewError.unavailable
    }

    func stopPreview() async { }
}

enum LiveActivityPlanBuilder {
    static let previewDuration: TimeInterval = 60 * 60

    static func schedule(
        snapshot: ScheduleSnapshot,
        settings: ReminderSettings,
        completionState: CompletionState,
        now: Date
    ) -> SharedActivitySchedule {
        guard settings.liveActivitiesEnabled else {
            return SharedActivitySchedule(isEnabled: false, generatedAt: now)
        }

        let segments = snapshot.occurrences
            .filter { !completionState.isPutOut($0.id) }
            .flatMap { occurrence in segments(for: occurrence, now: now) }

        return SharedActivitySchedule(isEnabled: true, segments: segments, generatedAt: now)
    }

    static func previewSegment(
        snapshot: ScheduleSnapshot,
        now: Date
    ) -> SharedActivitySegment? {
        guard let occurrence = snapshot.upcoming(relativeTo: LocalDate(date: now)).first else {
            return nil
        }

        return SharedActivitySegment(
            id: SystemIdentifiers.liveActivityPreviewScheduleID,
            occurrenceID: SystemIdentifiers.liveActivityPreviewOccurrenceID,
            collectionDate: occurrence.localDate.fullDescription,
            collectionDateShort: occurrence.localDate.shortDescription,
            containers: occurrence.containers.map {
                CollectionActivityAttributes.Container(
                    id: $0.id,
                    name: $0.sourceLabel,
                    symbolName: $0.displayMetadata.symbolName
                )
            },
            startDate: now,
            staleDate: now.addingTimeInterval(previewDuration)
        )
    }

    private static func segments(
        for occurrence: CollectionOccurrence,
        now: Date
    ) -> [SharedActivitySegment] {
        let windowStart = occurrence.localDate.adding(days: -1).date(hour: 18)
        let windowEnd = occurrence.localDate.date(hour: 9)
        guard windowEnd > now else { return [] }

        let totalDuration = windowEnd.timeIntervalSince(windowStart)
        let segmentCount = max(1, Int(ceil(totalDuration / (8 * 60 * 60))))
        let segmentDuration = totalDuration / Double(segmentCount)
        let containers = occurrence.containers.map {
            CollectionActivityAttributes.Container(
                id: $0.id,
                name: $0.sourceLabel,
                symbolName: $0.displayMetadata.symbolName
            )
        }

        return (0..<segmentCount).map { index in
            let startDate = windowStart.addingTimeInterval(Double(index) * segmentDuration)
            let staleDate = min(
                windowEnd,
                windowStart.addingTimeInterval(Double(index + 1) * segmentDuration)
            )
            return SharedActivitySegment(
                id: "\(occurrence.id)|segment-\(index)",
                occurrenceID: occurrence.id,
                collectionDate: occurrence.localDate.fullDescription,
                collectionDateShort: occurrence.localDate.shortDescription,
                containers: containers,
                startDate: startDate,
                staleDate: staleDate
            )
        }
    }
}
