import Foundation

struct ScheduleSnapshot: Codable, Equatable, Sendable {
    let propertyID: UUID
    let occurrences: [CollectionOccurrence]
    let providerIdentifier: String
    let providerDisplayName: String
    let fetchedAt: Date
    let authoritativeThrough: LocalDate?
    let lastRefreshAttemptAt: Date
    let lastRefreshError: String?

    init(
        propertyID: UUID,
        occurrences: [CollectionOccurrence],
        providerIdentifier: String,
        providerDisplayName: String,
        fetchedAt: Date,
        lastRefreshAttemptAt: Date? = nil,
        lastRefreshError: String? = nil
    ) {
        let sortedOccurrences = occurrences.sorted { lhs, rhs in
            if lhs.localDate == rhs.localDate {
                lhs.id < rhs.id
            } else {
                lhs.localDate < rhs.localDate
            }
        }

        self.propertyID = propertyID
        self.occurrences = sortedOccurrences
        self.providerIdentifier = providerIdentifier
        self.providerDisplayName = providerDisplayName
        self.fetchedAt = fetchedAt
        authoritativeThrough = sortedOccurrences.last?.localDate
        self.lastRefreshAttemptAt = lastRefreshAttemptAt ?? fetchedAt
        self.lastRefreshError = lastRefreshError
    }

    func recordingRefreshFailure(at attemptDate: Date, message: String) -> ScheduleSnapshot {
        ScheduleSnapshot(
            propertyID: propertyID,
            occurrences: occurrences,
            providerIdentifier: providerIdentifier,
            providerDisplayName: providerDisplayName,
            fetchedAt: fetchedAt,
            lastRefreshAttemptAt: attemptDate,
            lastRefreshError: message
        )
    }

    func upcoming(relativeTo date: LocalDate) -> [CollectionOccurrence] {
        occurrences.filter { $0.localDate >= date }
    }

    /// Returns scheduled collections in a half-open local-date window starting on `date`.
    /// Six weeks therefore means today through the following 41 local calendar days.
    func upcoming(relativeTo date: LocalDate, withinWeeks weeks: Int) -> [CollectionOccurrence] {
        guard weeks > 0 else { return [] }

        let endDate = date.adding(days: weeks * 7)
        return occurrences.filter { occurrence in
            occurrence.localDate >= date && occurrence.localDate < endDate
        }
    }
}
