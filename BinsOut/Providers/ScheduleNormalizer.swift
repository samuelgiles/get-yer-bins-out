import Foundation

enum ScheduleNormalizer {
    static func snapshot(
        property: Property,
        providerIdentifier: String,
        providerDisplayName: String,
        fetchedAt: Date,
        containers: [ProviderContainerSchedule]
    ) -> ScheduleSnapshot {
        var containersByDate: [LocalDate: [ContainerKind]] = [:]

        for containerSchedule in containers {
            let container = ContainerKind(
                sourceID: containerSchedule.sourceID,
                sourceLabel: containerSchedule.sourceLabel
            )

            for date in Set(containerSchedule.dates) {
                containersByDate[date, default: []].append(container)
            }
        }

        let occurrences = containersByDate.map { date, containers in
            CollectionOccurrence(propertyID: property.id, localDate: date, containers: containers)
        }

        return ScheduleSnapshot(
            propertyID: property.id,
            occurrences: occurrences,
            providerIdentifier: providerIdentifier,
            providerDisplayName: providerDisplayName,
            fetchedAt: fetchedAt
        )
    }
}

