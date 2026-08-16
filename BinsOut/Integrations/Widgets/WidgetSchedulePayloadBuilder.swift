import Foundation

enum WidgetSchedulePayloadBuilder {
    static func make(
        property: Property?,
        snapshot: ScheduleSnapshot?,
        now: Date
    ) -> WidgetSchedulePayload {
        guard let property else {
            return .empty
        }

        guard let snapshot else {
            return WidgetSchedulePayload(
                propertyDisplayName: property.displayName,
                occurrences: [],
                fetchedAt: nil,
                hasRefreshIssue: false
            )
        }

        let today = LocalDate(date: now)
        let occurrences = snapshot.upcoming(relativeTo: today).map { occurrence in
            WidgetCollectionOccurrence(
                id: occurrence.id,
                localDate: WidgetLocalDate(
                    year: occurrence.localDate.year,
                    month: occurrence.localDate.month,
                    day: occurrence.localDate.day
                ),
                containers: occurrence.containers.map { container in
                    WidgetContainer(
                        id: container.id,
                        name: container.sourceLabel,
                        symbolName: container.displayMetadata.symbolName
                    )
                }
            )
        }

        return WidgetSchedulePayload(
            propertyDisplayName: property.displayName,
            occurrences: occurrences,
            fetchedAt: snapshot.fetchedAt,
            hasRefreshIssue: snapshot.lastRefreshError != nil
        )
    }
}
