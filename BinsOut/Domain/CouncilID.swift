import Foundation

enum CouncilID: String, CaseIterable, Codable, Identifiable, Sendable {
    case bristolCityCouncil = "bristol-city-council"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bristolCityCouncil:
            "Bristol City Council"
        }
    }

    var isSupported: Bool {
        switch self {
        case .bristolCityCouncil:
            true
        }
    }
}

