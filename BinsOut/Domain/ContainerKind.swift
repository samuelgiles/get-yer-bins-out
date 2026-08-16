import Foundation

enum ContainerColorRole: String, Sendable {
    case black
    case green
    case blue
    case brown
    case garden
    case communal
    case unknown
}

struct ContainerDisplayMetadata: Equatable, Sendable {
    let symbolName: String
    let colorRole: ContainerColorRole
}

struct ContainerKind: Codable, Equatable, Hashable, Identifiable, Sendable {
    let sourceID: String
    let sourceLabel: String

    var id: String { sourceID }

    var displayMetadata: ContainerDisplayMetadata {
        let label = sourceLabel.lowercased()

        if label.contains("black") && (label.contains("recycl") || label.contains("box")) {
            return ContainerDisplayMetadata(symbolName: "shippingbox.fill", colorRole: .black)
        }
        if label.contains("green") && (label.contains("recycl") || label.contains("box")) {
            return ContainerDisplayMetadata(symbolName: "arrow.3.trianglepath", colorRole: .green)
        }
        if label.contains("blue") && (label.contains("bag") || label.contains("recycl")) {
            return ContainerDisplayMetadata(symbolName: "bag.fill", colorRole: .blue)
        }
        if label.contains("food") || label.contains("brown") {
            return ContainerDisplayMetadata(symbolName: "fork.knife", colorRole: .brown)
        }
        if label.contains("garden") {
            return ContainerDisplayMetadata(symbolName: "leaf.fill", colorRole: .garden)
        }
        if label.contains("communal") {
            return ContainerDisplayMetadata(symbolName: "building.2.fill", colorRole: .communal)
        }
        if label.contains("refuse") || label.contains("general") || label.contains("wheelie") || label.contains("waste") {
            return ContainerDisplayMetadata(symbolName: "trash.fill", colorRole: .black)
        }
        return ContainerDisplayMetadata(symbolName: "questionmark.circle.fill", colorRole: .unknown)
    }
}

