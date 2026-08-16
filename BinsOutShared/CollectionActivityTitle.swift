import Foundation

struct CollectionActivityDisplay: Equatable, Sendable {
    let title: String
    let symbolName: String

    static func make(for containers: [CollectionActivityAttributes.Container]) -> CollectionActivityDisplay {
        let labels = containers.map { $0.name.lowercased() }
        let hasGeneralWaste = labels.contains { label in
            label.contains("general waste")
                || label.contains("household waste")
                || label.contains("wheelie bin")
                || label.contains("rubbish")
                || label.contains("refuse")
        }
        let hasRecycling = labels.contains { label in
            label.contains("recycling")
                || label.contains("blue bag")
                || label.contains("black box")
                || label.contains("green box")
        }
        let hasGardenWaste = labels.contains { $0.contains("garden") }
        let hasFoodWaste = labels.contains { $0.contains("food waste") }

        let title: String
        if hasGeneralWaste && hasRecycling {
            title = "Bins + Recycling"
        } else if hasGeneralWaste && hasFoodWaste {
            title = "Bins + Food"
        } else if hasRecycling {
            title = "Recycling"
        } else if hasGeneralWaste {
            title = "Bins"
        } else if hasGardenWaste {
            title = "Garden waste"
        } else if hasFoodWaste {
            title = "Food waste"
        } else {
            title = containers.count == 1 ? containers[0].name : "Collection"
        }

        let symbolName: String
        if hasGeneralWaste {
            // A combined collection keeps the bin symbol: it is the clearest primary action.
            symbolName = "trash.fill"
        } else if hasRecycling {
            symbolName = "arrow.3.trianglepath"
        } else if hasGardenWaste {
            symbolName = "leaf.fill"
        } else {
            symbolName = "trash.fill"
        }

        return CollectionActivityDisplay(title: title, symbolName: symbolName)
    }

    /// Fits the Dynamic Island's narrow trailing region without removing the full date
    /// from the Lock Screen or VoiceOver label.
    static func dynamicIslandDate(for collectionDateShort: String) -> String {
        let components = collectionDateShort.split(separator: " ")
        guard components.count >= 2,
              components[0].allSatisfy({ $0.isNumber }) else {
            return collectionDateShort
        }

        return "\(components[0]) \(components[1])"
    }
}

enum CollectionActivityTitle {
    static func title(for containers: [CollectionActivityAttributes.Container]) -> String {
        CollectionActivityDisplay.make(for: containers).title
    }
}
