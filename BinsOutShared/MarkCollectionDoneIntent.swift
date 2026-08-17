#if !targetEnvironment(macCatalyst)
import AppIntents
import Foundation

struct MarkCollectionDoneIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Bins out"
    static let description = IntentDescription("Marks this collection’s containers as put out.")
    static let supportedModes: IntentModes = .background
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication

    @Parameter(title: "Collection")
    var occurrenceID: String

    init() { }

    init(occurrenceID: String) {
        self.occurrenceID = occurrenceID
    }

    func perform() async throws -> some IntentResult {
        try await CollectionCompletionCoordinator().markPutOut(occurrenceID: occurrenceID)
        return .result()
    }
}
#endif
