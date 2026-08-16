import Foundation

#if DEBUG
/// Fixed, privacy-safe WidgetKit preview data. This file belongs to the widget
/// target so previews do not depend on app-only services or fixture types.
enum WidgetPreviewData {
    static let date = Date(timeIntervalSince1970: 1_786_867_200)
    static let propertyDisplayName = "Preview residence"

    static let recyclingOnly = payload(
        id: "preview-recycling",
        containers: [
            container("preview-black-recycling-box", "Black recycling box", "shippingbox.fill"),
            container("preview-green-recycling-box", "Green recycling box", "arrow.3.trianglepath"),
        ]
    )

    static let wheelieBinMixed = payload(
        id: "preview-wheelie-bin-mixed",
        containers: [
            container("preview-wheelie-bin", "Black wheelie bin", "trash.fill"),
            container("preview-green-recycling-box", "Green recycling box", "arrow.3.trianglepath"),
            container("preview-food-bin", "Food waste bin", "fork.knife"),
            container("preview-blue-recycling-bag", "Blue recycling bag", "bag.fill"),
            container("preview-garden-bin", "Garden waste bin", "leaf.fill"),
        ]
    )

    static let gardenWaste = payload(
        id: "preview-garden-waste",
        containers: [
            container("preview-garden-bin", "Garden waste bin", "leaf.fill"),
        ]
    )

    static let staleRecycling = WidgetSchedulePayload(
        propertyDisplayName: propertyDisplayName,
        occurrences: recyclingOnly.occurrences,
        fetchedAt: date,
        hasRefreshIssue: true
    )

    static let empty = WidgetSchedulePayload(
        propertyDisplayName: propertyDisplayName,
        occurrences: [],
        fetchedAt: date,
        hasRefreshIssue: false
    )

    static let notConfigured = WidgetSchedulePayload.empty

    static func entry(payload: WidgetSchedulePayload) -> NextCollectionWidgetEntry {
        NextCollectionWidgetEntry(date: date, payload: payload)
    }

    private static func payload(
        id: String,
        containers: [WidgetContainer]
    ) -> WidgetSchedulePayload {
        WidgetSchedulePayload(
            propertyDisplayName: propertyDisplayName,
            occurrences: [
                WidgetCollectionOccurrence(
                    id: id,
                    localDate: WidgetLocalDate(year: 2026, month: 8, day: 18),
                    containers: containers
                ),
            ],
            fetchedAt: date,
            hasRefreshIssue: false
        )
    }

    private static func container(
        _ id: String,
        _ name: String,
        _ symbolName: String
    ) -> WidgetContainer {
        WidgetContainer(id: id, name: name, symbolName: symbolName)
    }
}
#endif
