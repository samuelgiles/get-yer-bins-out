import Foundation

enum CollectionRefreshMode: Equatable, Sendable {
    case ifStale
    case force
    case never
}

/// Decides whether answering a question is worth a council request. An intent has a short
/// execution budget, and a late Siri answer is worse than one drawn from a good cache.
struct CollectionRefreshPolicy: Equatable, Sendable {
    let staleAfter: TimeInterval
    let retryFailureAfter: TimeInterval

    static let `default` = CollectionRefreshPolicy(
        staleAfter: 12 * 60 * 60,
        retryFailureAfter: 15 * 60
    )

    func shouldRefresh(
        mode: CollectionRefreshMode,
        snapshot: ScheduleSnapshot?,
        today: LocalDate,
        now: Date
    ) -> Bool {
        guard mode != .never else { return false }

        guard let snapshot else { return true }

        // Back off after a failure so an offline device does not retry on every question.
        if snapshot.lastRefreshError != nil,
           now.timeIntervalSince(snapshot.lastRefreshAttemptAt) < retryFailureAfter {
            return false
        }

        if mode == .force { return true }

        if snapshot.upcoming(relativeTo: today).isEmpty { return true }

        return now.timeIntervalSince(snapshot.fetchedAt) > staleAfter
    }
}
