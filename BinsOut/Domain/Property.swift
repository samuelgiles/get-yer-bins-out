import Foundation

struct Property: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let council: CouncilID
    let uprn: String
    let displayName: String

    init(
        id: UUID = UUID(),
        council: CouncilID,
        uprn: String,
        displayName: String
    ) {
        self.id = id
        self.council = council
        self.uprn = uprn
        self.displayName = displayName
    }
}

