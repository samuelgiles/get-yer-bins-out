import Foundation

/// The small, read-only question set that Bins Out can answer in system experiences.
///
/// This intentionally isn't an Assistant Schema. Collection schedules and Bristol's
/// container guidance don't correspond to an Apple-defined schema domain, so ordinary
/// app-owned intents describe these app-specific queries without misrepresenting them.
enum SiriCollectionQuestion: Equatable, Sendable {
    case nextScheduledCollection
    case putOutTime
    case glassBottleSorting
}

struct SiriCollectionAnswer: Equatable, Sendable {
    let spokenText: String
    let supportingText: String
    let systemImageName: String
}

/// Produces concise answers from the same privacy-minimised App Group payload as the
/// widget. It never performs Bristol networking and has no access to a UPRN.
struct SiriCollectionAnswerService: Sendable {
    private let payloadStore: any WidgetPayloadStoring
    private let now: @Sendable () -> Date

    init(
        payloadStore: any WidgetPayloadStoring = FileWidgetPayloadStore(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.payloadStore = payloadStore
        self.now = now
    }

    func answer(to question: SiriCollectionQuestion) async -> SiriCollectionAnswer {
        if question == .glassBottleSorting {
            return Self.glassBottleSortingAnswer
        }

        do {
            let payload = try await payloadStore.load()
            return Self.answer(to: question, payload: payload, at: now())
        } catch {
            return SiriCollectionAnswer(
                spokenText: "I can’t read the saved collection schedule right now.",
                supportingText: "Open Bins Out to refresh the saved schedule.",
                systemImageName: "calendar.badge.exclamationmark"
            )
        }
    }

    static func answer(
        to question: SiriCollectionQuestion,
        payload: WidgetSchedulePayload,
        at date: Date
    ) -> SiriCollectionAnswer {
        if question == .glassBottleSorting {
            return glassBottleSortingAnswer
        }

        switch payload.presentation(at: date) {
        case .notConfigured:
            return SiriCollectionAnswer(
                spokenText: "Set up a property in Bins Out first.",
                supportingText: "Then I can answer questions about its scheduled collections.",
                systemImageName: "house"
            )

        case let .empty(propertyDisplayName, _):
            return SiriCollectionAnswer(
                spokenText: "There are no upcoming scheduled collections saved for \(propertyDisplayName).",
                supportingText: "Open Bins Out to refresh the schedule.",
                systemImageName: "calendar.badge.exclamationmark"
            )

        case let .scheduled(propertyDisplayName, occurrence, _, isStale):
            switch question {
            case .nextScheduledCollection:
                return nextCollectionAnswer(
                    propertyDisplayName: propertyDisplayName,
                    occurrence: occurrence,
                    isStale: isStale
                )
            case .putOutTime:
                return putOutTimeAnswer(
                    propertyDisplayName: propertyDisplayName,
                    occurrence: occurrence,
                    today: WidgetLocalDate(date: date),
                    isStale: isStale
                )
            case .glassBottleSorting:
                return glassBottleSortingAnswer
            }
        }
    }

    static let officialGlassBottleGuidanceURL = BristolOfficialLinks.blackRecyclingBox

    private static let glassBottleSortingAnswer = SiriCollectionAnswer(
        spokenText: "In Bristol, rinse glass bottles and jars and put them in the black recycling box. Put their lids in the green recycling box.",
        supportingText: "This does not apply to broken glass, window glass, drinking glass, or Pyrex. Check Bristol’s official guidance.",
        systemImageName: "shippingbox.fill"
    )

    private static func nextCollectionAnswer(
        propertyDisplayName: String,
        occurrence: WidgetCollectionOccurrence,
        isStale: Bool
    ) -> SiriCollectionAnswer {
        let containerText = containersDescription(for: occurrence)
        let freshness = freshnessText(isStale)

        return SiriCollectionAnswer(
            spokenText: "The next scheduled collection for \(propertyDisplayName) is \(occurrence.summary.title) on \(occurrence.localDate.fullDescription). Put out \(containerText).\(freshness)",
            supportingText: "Collection dates are scheduled dates, not confirmation that a crew completed collection.",
            systemImageName: occurrence.summary.symbolName
        )
    }

    private static func putOutTimeAnswer(
        propertyDisplayName: String,
        occurrence: WidgetCollectionOccurrence,
        today: WidgetLocalDate,
        isStale: Bool
    ) -> SiriCollectionAnswer {
        let containerText = containersDescription(for: occurrence)
        let freshness = freshnessText(isStale)

        if occurrence.localDate == today {
            return SiriCollectionAnswer(
                spokenText: "Today’s scheduled \(occurrence.summary.title) collection for \(propertyDisplayName) was due out yesterday evening. Put out \(containerText).\(freshness)",
                supportingText: "The collection date is \(occurrence.localDate.fullDescription).",
                systemImageName: occurrence.summary.symbolName
            )
        }

        let eveningBefore = occurrence.localDate.adding(days: -1)
        return SiriCollectionAnswer(
            spokenText: "Put out \(containerText) on the evening of \(eveningBefore.fullDescription) for \(propertyDisplayName)’s scheduled \(occurrence.localDate.fullDescription) collection.\(freshness)",
            supportingText: "The saved schedule uses Europe/London collection dates.",
            systemImageName: occurrence.summary.symbolName
        )
    }

    private static func containersDescription(for occurrence: WidgetCollectionOccurrence) -> String {
        let names = occurrence.containers.map(\.name)
        return names.isEmpty ? "the containers listed in Bins Out" : names.formatted(.list(type: .and))
    }

    private static func freshnessText(_ isStale: Bool) -> String {
        isStale ? " The saved schedule may be out of date." : ""
    }
}
