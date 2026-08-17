import Foundation

/// `IntentDialog(full:supporting:)` speaks one of these, never both: `supporting`
/// whenever a snippet is on screen, `full` otherwise. Every collection question returns a
/// snippet, so `supporting` is the usual one — and must read as a whole sentence alone,
/// not as a continuation of `fullText`.
struct CollectionAnswer: Equatable, Sendable {
    let fullText: String
    let supportingText: String
    let systemImageName: String
}

/// Every phrase describes a *scheduled* date; none may imply a completed collection.
enum CollectionAnswerPhrasing {
    static let officialGlassBottleGuidanceURL = BristolOfficialLinks.blackRecyclingBox

    /// Shown in the snippet, not spoken: a trailing legalism on every answer is one users
    /// learn to talk over.
    static let scheduledDatesCaveat = "Scheduled collection dates. They are not confirmation that a crew completed a collection."

    static func answer(
        to question: CollectionQuestion,
        context: CollectionAnswerContext
    ) -> CollectionAnswer {
        if question == .glassBottleSorting {
            return glassBottleSortingAnswer
        }

        switch context.state {
        case .unavailable:
            return CollectionAnswer(
                fullText: "I can’t read the saved collection schedule right now.",
                supportingText: "Open Bins Out to refresh the saved schedule.",
                systemImageName: "calendar.badge.exclamationmark"
            )

        case .notConfigured:
            return CollectionAnswer(
                fullText: "Set up a property in Bins Out first. Then I can answer questions about its scheduled collections.",
                supportingText: "Add a property in Bins Out first.",
                systemImageName: "house"
            )

        case let .noUpcoming(propertyDisplayName):
            return CollectionAnswer(
                fullText: "There are no upcoming scheduled collections saved for \(propertyDisplayName). Open Bins Out to refresh the schedule.",
                supportingText: "No upcoming dates saved for \(propertyDisplayName).",
                systemImageName: "calendar.badge.exclamationmark"
            )

        case let .scheduled(propertyDisplayName, next, following):
            switch question {
            case .nextScheduledCollection:
                return nextCollectionAnswer(
                    propertyDisplayName: propertyDisplayName,
                    occurrence: next,
                    following: following.first,
                    context: context
                )
            case .putOutTime:
                return putOutTimeAnswer(
                    propertyDisplayName: propertyDisplayName,
                    occurrence: next,
                    context: context
                )
            case .glassBottleSorting:
                return glassBottleSortingAnswer
            }
        }
    }

    static let glassBottleSortingAnswer = CollectionAnswer(
        fullText: "In Bristol, rinse glass bottles and jars and put them in the black recycling box. Put their lids in the green recycling box. This does not apply to broken glass, window glass, drinking glass, or Pyrex.",
        supportingText: "Bottles and jars in the black box, lids in the green box.",
        systemImageName: "shippingbox.fill"
    )

    static func containersDescription(for occurrence: CollectionOccurrence) -> String {
        let names = occurrence.containers.map(\.sourceLabel)
        return names.isEmpty ? "the containers listed in Bins Out" : names.formatted(.list(type: .and))
    }

    /// Matches the widget countdown's phrasing.
    static func countdownDescription(for date: LocalDate, relativeTo today: LocalDate) -> String {
        let days = LocalDate.calendar.dateComponents(
            [.day],
            from: today.dateAtNoon,
            to: date.dateAtNoon
        ).day ?? 0

        switch days {
        case ..<0: return "Collection passed"
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    private static func nextCollectionAnswer(
        propertyDisplayName: String,
        occurrence: CollectionOccurrence,
        following: CollectionOccurrence?,
        context: CollectionAnswerContext
    ) -> CollectionAnswer {
        let summary = occurrence.summary
        let containerText = containersDescription(for: occurrence)
        let when = countdownDescription(for: occurrence.localDate, relativeTo: context.today)
            .lowercased()

        var full = "The next scheduled collection for \(propertyDisplayName) is \(summary.title) on \(occurrence.localDate.fullDescription). Put out \(containerText)."
        // A continuation clause, so it belongs only in `full`.
        if let following {
            full += " Then \(following.summary.title.lowercased()) on \(following.localDate.fullDescription)."
        }

        var supporting = "\(summary.title) \(when)"
        if let following {
            supporting += ", then \(following.summary.title.lowercased()) on \(following.localDate.weekdayName)"
        }
        supporting += "."

        if context.isNextPutOut {
            full += " You’ve already marked these as put out."
            supporting = "Already put out. \(supporting)"
        }

        return CollectionAnswer(
            fullText: full + freshnessText(context),
            supportingText: supporting + shortFreshnessText(context),
            systemImageName: summary.symbolName
        )
    }

    private static func putOutTimeAnswer(
        propertyDisplayName: String,
        occurrence: CollectionOccurrence,
        context: CollectionAnswerContext
    ) -> CollectionAnswer {
        let summary = occurrence.summary
        let containerText = containersDescription(for: occurrence)

        if context.isNextPutOut {
            return CollectionAnswer(
                fullText: "You’ve already marked \(propertyDisplayName)’s \(occurrence.localDate.fullDescription) collection as put out.\(freshnessText(context))",
                supportingText: "Already put out.\(shortFreshnessText(context))",
                systemImageName: "checkmark.circle.fill"
            )
        }

        if occurrence.localDate == context.today {
            return CollectionAnswer(
                fullText: "Today’s scheduled \(summary.title) collection for \(propertyDisplayName) was due out yesterday evening. Put out \(containerText).\(freshnessText(context))",
                supportingText: "They were due out yesterday evening.\(shortFreshnessText(context))",
                systemImageName: summary.symbolName
            )
        }

        let eveningBefore = occurrence.localDate.adding(days: -1)
        return CollectionAnswer(
            fullText: "Put out \(containerText) on the evening of \(eveningBefore.fullDescription) for \(propertyDisplayName)’s scheduled \(occurrence.localDate.fullDescription) collection.\(freshnessText(context))",
            supportingText: "Put them out on \(eveningBefore.weekdayName) evening.\(shortFreshnessText(context))",
            systemImageName: summary.symbolName
        )
    }

    private static func freshnessText(_ context: CollectionAnswerContext) -> String {
        context.isStale ? " The saved schedule may be out of date." : ""
    }

    private static func shortFreshnessText(_ context: CollectionAnswerContext) -> String {
        context.isStale ? " This may be out of date." : ""
    }
}
