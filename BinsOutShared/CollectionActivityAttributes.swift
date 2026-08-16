import Foundation

#if !targetEnvironment(macCatalyst)
import ActivityKit
#endif

struct CollectionActivityAttributes: Codable, Hashable, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        let isPutOut: Bool
    }

    struct Container: Codable, Hashable, Sendable, Identifiable {
        let id: String
        let name: String
        let symbolName: String
    }

    let occurrenceID: String
    let scheduleID: String
    let collectionDate: String
    let collectionDateShort: String
    let containers: [Container]
}

#if !targetEnvironment(macCatalyst)
extension CollectionActivityAttributes: ActivityAttributes { }
#endif
