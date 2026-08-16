import Foundation

#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif

enum LiveActivityReconciliationResult: Equatable, Sendable {
    case disabled
    case unavailable
    case noUpcomingCollection
    case scheduled(segmentCount: Int)
}

enum LiveActivityPreviewError: Error, LocalizedError, Sendable {
    case unavailable

    var errorDescription: String? {
        "Live Activities are unavailable or disabled in System Settings."
    }
}

struct LiveActivityCoordinator: Sendable {
#if targetEnvironment(macCatalyst)
    func reconcile(
        schedule: SharedActivitySchedule,
        completionState: CompletionState,
        now: Date = .now
    ) async throws -> LiveActivityReconciliationResult {
        .unavailable
    }

    func isPreviewActive() -> Bool {
        false
    }

    func startPreview(_ segment: SharedActivitySegment, now: Date = .now) async throws {
        throw LiveActivityPreviewError.unavailable
    }

    func stopPreview() async { }
#else
    func reconcile(
        schedule: SharedActivitySchedule,
        completionState: CompletionState,
        now: Date = .now
    ) async throws -> LiveActivityReconciliationResult {
        let existingActivities = Activity<CollectionActivityAttributes>.activities
        let scheduledActivities = existingActivities.filter {
            !SystemIdentifiers.isLiveActivityPreview(scheduleID: $0.attributes.scheduleID)
        }

        guard schedule.isEnabled else {
            await end(scheduledActivities)
            return .disabled
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end(scheduledActivities)
            return .unavailable
        }

        let nextOccurrenceID = schedule.segments
            .filter { $0.staleDate > now && !completionState.isPutOut($0.occurrenceID) }
            .sorted { $0.startDate < $1.startDate }
            .first?
            .occurrenceID

        guard let nextOccurrenceID else {
            await end(scheduledActivities)
            return .noUpcomingCollection
        }

        let desiredSegments = schedule.segments.filter {
            $0.occurrenceID == nextOccurrenceID && $0.staleDate > now
        }
        let desiredIDs = Set(desiredSegments.map(\.id))
        await end(scheduledActivities.filter { !desiredIDs.contains($0.attributes.scheduleID) })

        let existingIDs = Set(
            scheduledActivities
                .filter { $0.activityState == .pending || $0.activityState == .active || $0.activityState == .stale }
                .map(\.attributes.scheduleID)
        )

        for segment in desiredSegments where !existingIDs.contains(segment.id) {
            try request(segment: segment, now: now)
        }

        return .scheduled(segmentCount: desiredSegments.count)
    }

    func isPreviewActive() -> Bool {
        Activity<CollectionActivityAttributes>.activities.contains {
            SystemIdentifiers.isLiveActivityPreview(scheduleID: $0.attributes.scheduleID)
                && ($0.activityState == .active || $0.activityState == .pending)
        }
    }

    func startPreview(_ segment: SharedActivitySegment, now: Date = .now) async throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityPreviewError.unavailable
        }

        await stopPreview()
        try request(segment: segment, now: now)
    }

    func stopPreview() async {
        await end(
            Activity<CollectionActivityAttributes>.activities.filter {
                SystemIdentifiers.isLiveActivityPreview(scheduleID: $0.attributes.scheduleID)
            }
        )
    }

    private func request(segment: SharedActivitySegment, now: Date) throws {
        let attributes = CollectionActivityAttributes(
            occurrenceID: segment.occurrenceID,
            scheduleID: segment.id,
            collectionDate: segment.collectionDate,
            collectionDateShort: segment.collectionDateShort,
            containers: segment.containers
        )
        let content = ActivityContent(
            state: CollectionActivityAttributes.ContentState(isPutOut: false),
            staleDate: segment.staleDate
        )

        if segment.startDate > now {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil,
                style: .standard,
                alertConfiguration: AlertConfiguration(
                    title: "Bins out",
                    body: "Your scheduled collection is \(segment.collectionDateShort).",
                    sound: .default
                ),
                start: segment.startDate
            )
        } else {
            _ = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil,
                style: .standard
            )
        }
    }

    private func end(_ activities: [Activity<CollectionActivityAttributes>]) async {
        for activity in activities {
            let finalContent = ActivityContent(
                state: CollectionActivityAttributes.ContentState(isPutOut: true),
                staleDate: nil
            )
            await activity.end(finalContent, dismissalPolicy: .immediate)
        }
    }
#endif
}
