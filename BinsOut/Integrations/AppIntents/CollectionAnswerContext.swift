import Foundation

/// Not an Assistant Schema: neither collection schedules nor municipal sorting rules
/// correspond to an Apple-defined schema domain.
enum CollectionQuestion: Equatable, Sendable {
    case nextScheduledCollection
    case putOutTime
    case glassBottleSorting
}

/// Resolved facts for the intents, snippets, and entity. Carries no UPRN: the property
/// is identified only by the user's own local label.
struct CollectionAnswerContext: Equatable, Sendable {
    enum State: Equatable, Sendable {
        case notConfigured
        case noUpcoming(propertyDisplayName: String)
        case scheduled(
            propertyDisplayName: String,
            next: CollectionOccurrence,
            following: [CollectionOccurrence]
        )
        /// Distinct from `notConfigured`: the saved data could not be read at all.
        case unavailable
    }

    let state: State
    let isNextPutOut: Bool
    let fetchedAt: Date?
    let refreshErrorMessage: String?
    let today: LocalDate

    init(
        state: State,
        isNextPutOut: Bool = false,
        fetchedAt: Date? = nil,
        refreshErrorMessage: String? = nil,
        today: LocalDate
    ) {
        self.state = state
        self.isNextPutOut = isNextPutOut
        self.fetchedAt = fetchedAt
        self.refreshErrorMessage = refreshErrorMessage
        self.today = today
    }

    var propertyDisplayName: String? {
        switch state {
        case .notConfigured, .unavailable:
            nil
        case let .noUpcoming(propertyDisplayName):
            propertyDisplayName
        case let .scheduled(propertyDisplayName, _, _):
            propertyDisplayName
        }
    }

    var nextOccurrence: CollectionOccurrence? {
        guard case let .scheduled(_, next, _) = state else { return nil }
        return next
    }

    var followingOccurrences: [CollectionOccurrence] {
        guard case let .scheduled(_, _, following) = state else { return [] }
        return following
    }

    var isStale: Bool { refreshErrorMessage != nil }
}
