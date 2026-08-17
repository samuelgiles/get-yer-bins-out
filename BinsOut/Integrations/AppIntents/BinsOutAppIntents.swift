#if !targetEnvironment(macCatalyst)
import AppIntents
import Foundation

/// App-owned collection questions, answered from the app's own persisted property and
/// schedule. Each returns an entity other actions can chain, dialog, and a snippet.
struct NextScheduledCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Get next collection"
    static let description = IntentDescription("Answers with the next scheduled collection for your saved property.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some ReturnsValue<ScheduledCollectionEntity?>
        & ProvidesDialog & ShowsSnippetIntent {
        try await collectionResult(for: .nextScheduledCollection)
    }
}

struct PutOutTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get bin put-out time"
    static let description = IntentDescription("Answers when to put out containers for the next scheduled collection.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some ReturnsValue<ScheduledCollectionEntity?>
        & ProvidesDialog & ShowsSnippetIntent {
        try await collectionResult(for: .putOutTime)
    }
}

struct GlassBottleSortingIntent: AppIntent {
    static let title: LocalizedStringResource = "Sort glass bottles"
    static let description = IntentDescription("Answers where Bristol glass bottles and jars go.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some ProvidesDialog & ShowsSnippetIntent {
        let answer = CollectionAnswerPhrasing.glassBottleSortingAnswer
        return .result(
            dialog: dialog(for: answer),
            snippetIntent: GlassSortingSnippetIntent()
        )
    }
}

/// A separate explicit action preserves the official Bristol route without opening a
/// website merely because someone asked the sorting question.
struct OpenGlassBottleGuidanceIntent: AppIntent {
    static let title: LocalizedStringResource = "Open official glass bottle guidance"
    static let description = IntentDescription("Opens Bristol City Council’s current guidance for glass bottles and jars.")
    static let supportedModes: IntentModes = .foreground(.immediate)
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some IntentResult & OpensIntent {
        .result(opensIntent: OpenURLIntent(CollectionAnswerPhrasing.officialGlassBottleGuidanceURL))
    }
}

struct BinsOutAppShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .teal

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NextScheduledCollectionIntent(),
            phrases: [
                "When is my next bin day in \(.applicationName)",
                "When is my next collection in \(.applicationName)",
                "What goes out next in \(.applicationName)"
            ],
            shortTitle: "Next collection",
            systemImageName: "calendar.badge.clock"
        )

        AppShortcut(
            intent: PutOutTimeIntent(),
            phrases: [
                "When should the bin next go out with \(.applicationName)",
                "When should I put out my bins with \(.applicationName)",
                "When should bins go out in \(.applicationName)",
                "When should I put out recycling with \(.applicationName)"
            ],
            shortTitle: "When to put bins out",
            systemImageName: "clock.badge.checkmark"
        )

        AppShortcut(
            intent: RefreshScheduleIntent(),
            phrases: [
                "Refresh my bin schedule in \(.applicationName)",
                "Check for new collection dates in \(.applicationName)",
                "Update my collection dates in \(.applicationName)"
            ],
            shortTitle: "Refresh schedule",
            systemImageName: "arrow.clockwise"
        )

        AppShortcut(
            intent: GlassBottleSortingIntent(),
            phrases: [
                "Which bin do glass bottles go in with \(.applicationName)",
                "Where do glass jars go with \(.applicationName)",
                "How do I recycle glass bottles with \(.applicationName)"
            ],
            shortTitle: "Sort glass bottles",
            systemImageName: "shippingbox.fill"
        )

        AppShortcut(
            intent: OpenGlassBottleGuidanceIntent(),
            phrases: [
                "Open official glass bottle guidance in \(.applicationName)",
                "Show Bristol glass bottle guidance in \(.applicationName)"
            ],
            shortTitle: "Official glass guidance",
            systemImageName: "arrow.up.right.square"
        )
    }
}

private func collectionResult(
    for question: CollectionQuestion
) async throws -> some ReturnsValue<ScheduledCollectionEntity?> & ProvidesDialog & ShowsSnippetIntent {
    let context = await CollectionAnswerService().context()
    let answer = CollectionAnswerPhrasing.answer(to: question, context: context)

    return .result(
        value: context.nextEntity,
        dialog: dialog(for: answer),
        snippetIntent: NextCollectionSnippetIntent()
    )
}

private func dialog(for answer: CollectionAnswer) -> IntentDialog {
    IntentDialog(
        full: "\(answer.fullText)",
        supporting: "\(answer.supportingText)",
        systemImageName: answer.systemImageName
    )
}
#endif
