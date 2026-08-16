import Foundation

struct CompletionRecord: Codable, Equatable, Sendable {
    let occurrenceID: String
    let putOutAt: Date
    let undoneAt: Date?

    var isPutOut: Bool { undoneAt == nil }
}

struct CompletionState: Codable, Equatable, Sendable {
    private(set) var records: [String: CompletionRecord] = [:]

    func isPutOut(_ occurrenceID: String) -> Bool {
        records[occurrenceID]?.isPutOut == true
    }

    mutating func markPutOut(_ occurrenceID: String, at date: Date) {
        guard !isPutOut(occurrenceID) else { return }
        records[occurrenceID] = CompletionRecord(
            occurrenceID: occurrenceID,
            putOutAt: date,
            undoneAt: nil
        )
    }

    mutating func undo(_ occurrenceID: String, at date: Date) {
        guard let record = records[occurrenceID], record.isPutOut else { return }
        records[occurrenceID] = CompletionRecord(
            occurrenceID: occurrenceID,
            putOutAt: record.putOutAt,
            undoneAt: date
        )
    }
}

protocol CompletionStoring: Sendable {
    func load() async throws -> CompletionState
    func save(_ state: CompletionState) async throws
}

actor FileCompletionStore: CompletionStoring {
    private let directory: URL
    private let fileURL: URL

    init(baseDirectory: URL? = nil) {
        let directory = baseDirectory ?? AppGroupConfiguration.containerURL()
        self.directory = directory
        fileURL = directory.appending(path: "completion-state.json", directoryHint: .notDirectory)
    }

    func load() async throws -> CompletionState {
        guard FileManager.default.fileExists(atPath: fileURL.path()) else {
            return CompletionState()
        }
        return try JSONDecoder().decode(CompletionState.self, from: Data(contentsOf: fileURL))
    }

    func save(_ state: CompletionState) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(state).write(
            to: fileURL,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}

actor VolatileCompletionStore: CompletionStoring {
    private var state = CompletionState()

    func load() async throws -> CompletionState { state }

    func save(_ state: CompletionState) async throws {
        self.state = state
    }
}
