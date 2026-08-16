import Foundation

struct FixtureCollectionProvider: CollectionProvider {
    let identifier = "fixture"
    let displayName = "Sample schedule"

    private let now: @Sendable () -> Date

    init(now: @escaping @Sendable () -> Date = { Date.now }) {
        self.now = now
    }

    func schedule(for property: Property) async throws -> ScheduleSnapshot {
        guard property.council == .bristolCityCouncil else {
            throw CollectionProviderError.unsupportedCouncil
        }

        _ = try UPRNValidator.validated(property.uprn)

        let fetchedAt = now()
        let today = LocalDate(date: fetchedAt)
        let weeklyFoodDates = stride(from: 2, to: 24 * 7, by: 7).map(today.adding(days:))
        let recyclingDates = stride(from: 2, to: 24 * 7, by: 14).map(today.adding(days:))
        let generalWasteDates = stride(from: 9, to: 24 * 7, by: 14).map(today.adding(days:))
        let containers = [
            ProviderContainerSchedule(
                sourceID: "fixture-black-recycling-box",
                sourceLabel: "Black recycling box",
                dates: recyclingDates
            ),
            ProviderContainerSchedule(
                sourceID: "fixture-green-recycling-box",
                sourceLabel: "Green recycling box",
                dates: recyclingDates
            ),
            ProviderContainerSchedule(
                sourceID: "fixture-food-bin",
                sourceLabel: "Brown food bin",
                dates: weeklyFoodDates
            ),
            ProviderContainerSchedule(
                sourceID: "fixture-general-waste",
                sourceLabel: "Black wheelie bin",
                dates: generalWasteDates
            ),
        ]

        return ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: identifier,
            providerDisplayName: displayName,
            fetchedAt: fetchedAt,
            containers: containers
        )
    }
}
