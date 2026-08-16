import Foundation

protocol CollectionProvider: Sendable {
    var identifier: String { get }
    var displayName: String { get }

    func schedule(for property: Property) async throws -> ScheduleSnapshot
}

enum CollectionProviderError: Error, Equatable, LocalizedError, Sendable {
    case unsupportedCouncil
    case invalidResponse
    case unauthorized
    case httpStatus(Int)
    case apiResponse(String)
    case noCollections
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .unsupportedCouncil:
            "This council is not supported yet."
        case .invalidResponse:
            "The collection service returned an invalid response."
        case .unauthorized:
            "The Bristol public client configuration was not accepted."
        case .httpStatus:
            "The collection service is unavailable right now."
        case .apiResponse(let message):
            message.isEmpty ? "The collection service could not find a schedule." : message
        case .noCollections:
            "No upcoming scheduled collections were returned for that UPRN."
        case .malformedResponse:
            "The collection service returned data the app could not read."
        }
    }
}

struct ProviderContainerSchedule: Equatable, Sendable {
    let sourceID: String
    let sourceLabel: String
    let dates: [LocalDate]
}
