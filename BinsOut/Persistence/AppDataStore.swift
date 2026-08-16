import Foundation

struct PersistedAppData: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let property: Property
    let propertyUpdatedAt: Date
    let snapshot: ScheduleSnapshot?
    var settings: UserSettings

    init(
        property: Property,
        snapshot: ScheduleSnapshot?,
        propertyUpdatedAt: Date = .distantPast,
        settings: UserSettings = UserSettings()
    ) {
        schemaVersion = 3
        self.property = property
        self.propertyUpdatedAt = propertyUpdatedAt
        self.snapshot = snapshot
        self.settings = settings
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case property
        case propertyUpdatedAt
        case snapshot
        case settings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        property = try container.decode(Property.self, forKey: .property)
        propertyUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .propertyUpdatedAt) ?? .distantPast
        snapshot = try container.decodeIfPresent(ScheduleSnapshot.self, forKey: .snapshot)
        settings = try container.decodeIfPresent(UserSettings.self, forKey: .settings) ?? UserSettings()
    }
}

protocol AppDataStoring: Sendable {
    func load() async throws -> PersistedAppData?
    func save(_ data: PersistedAppData) async throws
}

actor FileAppDataStore: AppDataStoring {
    private let directory: URL
    private let fileURL: URL

    init(baseDirectory: URL? = nil) {
        let resolvedDirectory = baseDirectory
            ?? AppGroupConfiguration.containerURL()
        directory = resolvedDirectory
        fileURL = resolvedDirectory.appending(path: "app-data.json", directoryHint: .notDirectory)
    }

    func load() async throws -> PersistedAppData? {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(PersistedAppData.self, from: data)
    }

    func save(_ data: PersistedAppData) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = try JSONEncoder().encode(data)
        try encoded.write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
