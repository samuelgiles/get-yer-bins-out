#if !targetEnvironment(macCatalyst)
import AppIntents
import Foundation

/// App-owned collection questions run in the main app process on iOS and iPadOS 27.
/// They use `SiriCollectionAnswerService`, whose only data source is the UPRN-free App
/// Group widget payload; no intent performs council networking.
struct NextScheduledCollectionIntent: AppIntent {
    static let title: LocalizedStringResource = "Get next collection"
    static let description = IntentDescription("Answers with the next scheduled collection saved in Bins Out.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = await SiriCollectionAnswerService().answer(to: .nextScheduledCollection)
        return .result(dialog: dialog(for: answer))
    }
}

struct PutOutTimeIntent: AppIntent {
    static let title: LocalizedStringResource = "Get bin put-out time"
    static let description = IntentDescription("Answers when to put out containers for the next scheduled collection.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = await SiriCollectionAnswerService().answer(to: .putOutTime)
        return .result(dialog: dialog(for: answer))
    }
}

struct GlassBottleSortingIntent: AppIntent {
    static let title: LocalizedStringResource = "Sort glass bottles"
    static let description = IntentDescription("Answers where Bristol glass bottles and jars go.")
    static let supportedModes: IntentModes = .background
    static let allowedExecutionTargets: ExecutionTargets = .main

    init() { }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = await SiriCollectionAnswerService().answer(to: .glassBottleSorting)
        return .result(dialog: dialog(for: answer))
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
        .result(opensIntent: OpenURLIntent(SiriCollectionAnswerService.officialGlassBottleGuidanceURL))
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

private func dialog(for answer: SiriCollectionAnswer) -> IntentDialog {
    IntentDialog(
        full: "\(answer.spokenText)",
        supporting: "\(answer.supportingText)",
        systemImageName: answer.systemImageName
    )
}
#endif
