import Foundation

extension CollectionOccurrence {
    var sharedContainers: [WidgetContainer] {
        containers.map { container in
            WidgetContainer(
                id: container.id,
                name: container.sourceLabel,
                symbolName: container.displayMetadata.symbolName
            )
        }
    }

    /// Shared with the widget so the two cannot describe the same collection differently.
    var summary: WidgetCollectionSummary {
        WidgetCollectionSummary.make(for: sharedContainers)
    }
}
