#if !targetEnvironment(macCatalyst)
import AppIntents
import Foundation

/// A scheduled collection, as Siri, Spotlight, and Shortcuts display and chain it. Its
/// identifier is the existing occurrence ID — a random property UUID, a local date, and
/// the council's own container IDs — so it carries no UPRN and no address.
struct ScheduledCollectionEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Scheduled collection",
        numericFormat: "\(placeholder: .int) scheduled collections"
    )

    static let defaultQuery = ScheduledCollectionQuery()

    let id: String

    private let localDate: LocalDate
    private let baseSymbolName: String

    // `@EntityProperty` rather than App Intents' `@Property` shorthand: this app has its
    // own `Property` domain type, and the shorthand resolves to that instead.
    @EntityProperty(title: "Property")
    var propertyName: String

    /// Midday in `Europe/London`: the council publishes date-only values, and midday keeps
    /// the day intact for anything that converts to UTC.
    @EntityProperty(title: "Collection date")
    var collectionDate: Date

    @EntityProperty(title: "Collection")
    var summary: String

    @EntityProperty(title: "Containers")
    var containers: [String]

    @EntityProperty(title: "Already put out")
    var isPutOut: Bool

    @EntityProperty(title: "Put out on the evening of")
    var putOutDate: Date

    init(
        occurrence: CollectionOccurrence,
        propertyName: String,
        isPutOut: Bool
    ) {
        let occurrenceSummary = occurrence.summary

        id = occurrence.id
        localDate = occurrence.localDate
        baseSymbolName = occurrenceSummary.symbolName
        self.propertyName = propertyName
        collectionDate = occurrence.localDate.dateAtNoon
        summary = occurrenceSummary.title
        containers = occurrence.containers.map(\.sourceLabel)
        self.isPutOut = isPutOut
        putOutDate = occurrence.localDate.adding(days: -1).date(hour: 18)
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(summary) · \(localDate.fullDescription)",
            subtitle: "\(subtitleText)",
            image: .init(systemName: symbolName)
        )
    }

    private var subtitleText: String {
        let containerList = containers.isEmpty
            ? "See Bins Out for the container list"
            : containers.formatted(.list(type: .and))
        return isPutOut
            ? "\(propertyName) — already put out: \(containerList)"
            : "\(propertyName) — put out \(containerList)"
    }

    private var symbolName: String {
        isPutOut ? "checkmark.circle.fill" : baseSymbolName
    }
}

extension CollectionAnswerContext {
    var nextEntity: ScheduledCollectionEntity? {
        guard case let .scheduled(propertyDisplayName, next, _) = state else { return nil }
        return ScheduledCollectionEntity(
            occurrence: next,
            propertyName: propertyDisplayName,
            isPutOut: isNextPutOut
        )
    }

    var upcomingEntities: [ScheduledCollectionEntity] {
        guard case let .scheduled(propertyDisplayName, next, following) = state else { return [] }
        return ([next] + following).map { occurrence in
            ScheduledCollectionEntity(
                occurrence: occurrence,
                propertyName: propertyDisplayName,
                isPutOut: occurrence.id == next.id ? isNextPutOut : false
            )
        }
    }
}

/// Never refreshes: resolving an identifier the user already picked is no reason to
/// contact the council, and Shortcuts editing should stay instant.
struct ScheduledCollectionQuery: EntityQuery {
    static var allowedExecutionTargets: ExecutionTargets { .main }

    init() { }

    func entities(for identifiers: [String]) async throws -> [ScheduledCollectionEntity] {
        let wanted = Set(identifiers)
        return await upcoming().filter { wanted.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ScheduledCollectionEntity] {
        await upcoming()
    }

    private func upcoming() async -> [ScheduledCollectionEntity] {
        await CollectionAnswerService().context(refresh: .never).upcomingEntities
    }
}
#endif
