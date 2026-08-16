import Foundation

#if DEBUG
actor PreviewAppDataStore: AppDataStoring {
    private var data: PersistedAppData?

    init(data: PersistedAppData? = nil) {
        self.data = data
    }

    func load() async throws -> PersistedAppData? {
        data
    }

    func save(_ data: PersistedAppData) async throws {
        self.data = data
    }
}

@MainActor
enum PreviewData {
    static let property = Property(
        id: fixtureUUID("B1A50000-0000-4000-8000-000000000001"),
        council: .bristolCityCouncil,
        uprn: "001234567890",
        displayName: "Home"
    )

    static let fetchedAt = Date(timeIntervalSince1970: 1_786_867_200)

    static let snapshot: ScheduleSnapshot = {
        let dates = [
            ProviderContainerSchedule(
                sourceID: "preview-black-box",
                sourceLabel: "Black recycling box",
                dates: [
                    fixtureDate(year: 2026, month: 8, day: 21),
                    fixtureDate(year: 2026, month: 10, day: 9),
                ]
            ),
            ProviderContainerSchedule(
                sourceID: "preview-green-box",
                sourceLabel: "Green recycling box",
                dates: [fixtureDate(year: 2026, month: 8, day: 21)]
            ),
            ProviderContainerSchedule(
                sourceID: "preview-food",
                sourceLabel: "Brown food bin",
                dates: [
                    fixtureDate(year: 2026, month: 8, day: 21),
                    fixtureDate(year: 2026, month: 8, day: 28),
                    fixtureDate(year: 2026, month: 10, day: 9),
                ]
            ),
            ProviderContainerSchedule(
                sourceID: "preview-general",
                sourceLabel: "Black wheelie bin",
                dates: [fixtureDate(year: 2026, month: 8, day: 28)]
            ),
        ]
        return ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: "fixture",
            providerDisplayName: "Sample schedule",
            fetchedAt: fetchedAt,
            containers: dates
        )
    }()

    static func model(property: Property? = property, snapshot: ScheduleSnapshot? = snapshot) -> AppModel {
        let previewDate = Date(timeIntervalSince1970: 1_786_867_200)
        let model = AppModel(
            provider: FixtureCollectionProvider(now: { previewDate }),
            store: PreviewAppDataStore(),
            now: { previewDate }
        )
        model.prepareForPreview(property: property, snapshot: snapshot)
        return model
    }

    private static func fixtureUUID(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Preview UUID must be valid")
        }
        return uuid
    }

    private static func fixtureDate(year: Int, month: Int, day: Int) -> LocalDate {
        do {
            return try LocalDate(year: year, month: month, day: day)
        } catch {
            preconditionFailure("Preview date must be valid")
        }
    }
}
#endif
