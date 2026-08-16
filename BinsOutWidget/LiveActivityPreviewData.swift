import Foundation

#if DEBUG
/// Target-local Live Activity preview fixtures. They are fixed and synthetic so
/// the ActivityKit canvas does not require a scheduled activity or app data.
enum LiveActivityPreviewData {
    static let recycling = attributes(
        id: "preview-live-recycling",
        containers: [
            container("preview-black-recycling-box", "Black recycling box", "shippingbox.fill"),
            container("preview-green-recycling-box", "Green recycling box", "arrow.3.trianglepath"),
        ]
    )

    static let wheelieBinMixed = attributes(
        id: "preview-live-wheelie-mixed",
        containers: [
            container("preview-wheelie-bin", "Black wheelie bin", "trash.fill"),
            container("preview-green-recycling-box", "Green recycling box", "arrow.3.trianglepath"),
            container("preview-food-bin", "Food waste bin", "fork.knife"),
        ]
    )

    static let gardenWaste = attributes(
        id: "preview-live-garden-waste",
        containers: [
            container("preview-garden-bin", "Garden waste bin", "leaf.fill"),
        ]
    )

    static let upcoming = CollectionActivityAttributes.ContentState(isPutOut: false)
    static let complete = CollectionActivityAttributes.ContentState(isPutOut: true)

    private static func attributes(
        id: String,
        containers: [CollectionActivityAttributes.Container]
    ) -> CollectionActivityAttributes {
        CollectionActivityAttributes(
            occurrenceID: id,
            scheduleID: "\(id)|segment-0",
            collectionDate: "Tuesday, 18 August 2026",
            collectionDateShort: "18 Aug 2026",
            containers: containers
        )
    }

    private static func container(
        _ id: String,
        _ name: String,
        _ symbolName: String
    ) -> CollectionActivityAttributes.Container {
        CollectionActivityAttributes.Container(id: id, name: name, symbolName: symbolName)
    }
}
#endif
