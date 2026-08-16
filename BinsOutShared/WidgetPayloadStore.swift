import Foundation

protocol WidgetPayloadStoring: Sendable {
    func load() async throws -> WidgetSchedulePayload
    func save(_ payload: WidgetSchedulePayload) async throws
}

actor FileWidgetPayloadStore: WidgetPayloadStoring {
    private let directory: URL
    private let fileURL: URL

    init(baseDirectory: URL? = nil) {
        let directory = baseDirectory ?? AppGroupConfiguration.containerURL()
        self.directory = directory
        fileURL = directory.appending(path: "widget-schedule.json", directoryHint: .notDirectory)
    }

    func load() async throws -> WidgetSchedulePayload {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return .empty
        }
        return try JSONDecoder().decode(WidgetSchedulePayload.self, from: Data(contentsOf: fileURL))
    }

    func save(_ payload: WidgetSchedulePayload) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(payload).write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
