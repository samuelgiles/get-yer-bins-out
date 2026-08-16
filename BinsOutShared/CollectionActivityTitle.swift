import Foundation

enum CollectionActivityTitle {
    static func title(for containers: [CollectionActivityAttributes.Container]) -> String {
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
        let hasFoodWaste = labels.contains { $0.contains("food waste") }

        if hasGeneralWaste && hasRecycling {
            return "Bins + Recycling"
        }
        if hasGeneralWaste && hasFoodWaste {
            return "Bins + Food"
        }
        if hasRecycling {
            return "Recycling"
        }
        if hasGeneralWaste {
            return "Bins"
        }
        if hasFoodWaste {
            return "Food waste"
        }
        return containers.count == 1 ? containers[0].name : "Collection"
    }
}
