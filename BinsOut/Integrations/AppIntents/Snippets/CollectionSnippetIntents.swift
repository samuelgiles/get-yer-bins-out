#if !targetEnvironment(macCatalyst)
import AppIntents
import Foundation

/// Re-resolves the context on every `perform()` rather than capturing it, so `reload()`
/// after a button tap redraws current state instead of the answer Siri first gave.
struct NextCollectionSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Next collection snippet"
    static let isDiscoverable = false
    static var allowedExecutionTargets: ExecutionTargets { .main }

    init() { }

    func perform() async throws -> some ShowsSnippetView {
        let context = await CollectionAnswerService().context(refresh: .never)
        return .result(view: NextCollectionSnippetView(context: context))
    }
}

struct GlassSortingSnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "Glass sorting snippet"
    static let isDiscoverable = false
    static var allowedExecutionTargets: ExecutionTargets { .main }

    init() { }

    func perform() async throws -> some ShowsSnippetView {
        .result(view: GlassSortingSnippetView())
    }
}

struct PutOutFromSnippetIntent: AppIntent {
    static let title: LocalizedStringResource = "Mark bins as put out"
    static let description = IntentDescription("Marks the containers for a scheduled collection as put out.")
    static let supportedModes: IntentModes = .background
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresLocalDeviceAuthentication
    static var allowedExecutionTargets: ExecutionTargets { .main }

    @Parameter(title: "Collection")
    var occurrenceID: String

    init() { }

    init(occurrenceID: String) {
        self.occurrenceID = occurrenceID
    }

    func perform() async throws -> some IntentResult {
        try await CollectionCompletionCoordinator().markPutOut(occurrenceID: occurrenceID)
        NextCollectionSnippetIntent.reload()
        return .result()
    }
}

struct RefreshScheduleIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh collection schedule"
    static let description = IntentDescription("Fetches the latest scheduled collections for the saved property.")
    static let supportedModes: IntentModes = .background
    static var allowedExecutionTargets: ExecutionTargets { .main }

    init() { }

    func perform() async throws -> some ReturnsValue<ScheduledCollectionEntity?>
        & ProvidesDialog & ShowsSnippetIntent {
        let context = await CollectionAnswerService().context(refresh: .force)
        NextCollectionSnippetIntent.reload()

        let answer = CollectionAnswerPhrasing.answer(to: .nextScheduledCollection, context: context)
        return .result(
            value: context.nextEntity,
            dialog: IntentDialog(
                full: "\(answer.fullText)",
                supporting: "\(answer.supportingText)",
                systemImageName: answer.systemImageName
            ),
            snippetIntent: NextCollectionSnippetIntent()
        )
    }
}
#endif
