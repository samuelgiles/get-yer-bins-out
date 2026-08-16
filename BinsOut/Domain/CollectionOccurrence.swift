import Foundation

struct CollectionOccurrence: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let localDate: LocalDate
    let containers: [ContainerKind]

    init(propertyID: UUID, localDate: LocalDate, containers: [ContainerKind]) {
        let uniqueContainers = Dictionary(containers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            .values
            .sorted { lhs, rhs in
                if lhs.sourceLabel == rhs.sourceLabel {
                    lhs.id < rhs.id
                } else {
                    lhs.sourceLabel.localizedStandardCompare(rhs.sourceLabel) == .orderedAscending
                }
            }
        let normalizedIDs = uniqueContainers
            .map(\.id)
            .sorted()
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")

        id = "\(propertyID.uuidString.lowercased())|\(localDate.rawValue)|\(normalizedIDs)"
        self.localDate = localDate
        self.containers = uniqueContainers
    }
}

