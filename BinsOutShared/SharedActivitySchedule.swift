import Foundation

struct SharedActivitySegment: Codable, Equatable, Sendable, Identifiable {
    let id: String
    let occurrenceID: String
    let collectionDate: String
    let collectionDateShort: String
    let containers: [CollectionActivityAttributes.Container]
    let startDate: Date
    let staleDate: Date
}

struct SharedActivitySchedule: Codable, Equatable, Sendable {
    var isEnabled = false
    var segments: [SharedActivitySegment] = []
    var generatedAt = Date.distantPast
}

protocol SharedActivityScheduleStoring: Sendable {
    func load() async throws -> SharedActivitySchedule
    func save(_ schedule: SharedActivitySchedule) async throws
}

actor FileSharedActivityScheduleStore: SharedActivityScheduleStoring {
    private let directory: URL
    private let fileURL: URL

    init(baseDirectory: URL? = nil) {
        let directory = baseDirectory ?? AppGroupConfiguration.containerURL()
        self.directory = directory
        fileURL = directory.appending(path: "activity-schedule.json", directoryHint: .notDirectory)
    }

    func load() async throws -> SharedActivitySchedule {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return SharedActivitySchedule()
        }
        return try JSONDecoder().decode(SharedActivitySchedule.self, from: Data(contentsOf: fileURL))
    }

    func save(_ schedule: SharedActivitySchedule) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(schedule).write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
