import Foundation

enum BinsOutCollectionWidget {
    static let kind = "BinsOutNextCollectionWidget"

    static var collectionURL: URL? {
        var components = URLComponents()
        components.scheme = "binsout"
        components.host = "collection"
        return components.url
    }
}

/// The app's privacy-minimised hand-off to WidgetKit.
///
/// It deliberately contains no UPRN, council credentials, raw provider response,
/// or EventKit data. The widget reads this payload from the App Group and
/// never contacts Bristol itself.
struct WidgetSchedulePayload: Codable, Equatable, Sendable {
    let propertyDisplayName: String?
    let occurrences: [WidgetCollectionOccurrence]
    let fetchedAt: Date?
    let hasRefreshIssue: Bool

    init(
        propertyDisplayName: String?,
        occurrences: [WidgetCollectionOccurrence],
        fetchedAt: Date?,
        hasRefreshIssue: Bool
    ) {
        self.propertyDisplayName = propertyDisplayName
        self.occurrences = occurrences.sorted { $0.localDate < $1.localDate }
        self.fetchedAt = fetchedAt
        self.hasRefreshIssue = hasRefreshIssue
    }

    static let empty = WidgetSchedulePayload(
        propertyDisplayName: nil,
        occurrences: [],
        fetchedAt: nil,
        hasRefreshIssue: false
    )

    func presentation(at date: Date) -> WidgetSchedulePresentation {
        guard let propertyDisplayName else {
            return .notConfigured
        }

        let today = WidgetLocalDate(date: date)
        guard let occurrence = occurrences.first(where: { $0.localDate >= today }) else {
            return .empty(propertyDisplayName: propertyDisplayName, fetchedAt: fetchedAt)
        }

        return .scheduled(
            propertyDisplayName: propertyDisplayName,
            occurrence: occurrence,
            fetchedAt: fetchedAt,
            isStale: hasRefreshIssue
        )
    }

    /// WidgetKit may render later than the requested time. The payload contains
    /// every known upcoming occurrence, so date-only entries move to the next
    /// known collection at the start of the following Europe/London day.
    func timelineDates(startingAt date: Date) -> [Date] {
        let currentDate = WidgetLocalDate(date: date)
        let transitionDates = Set(
            occurrences
                .filter { $0.localDate >= currentDate }
                .map { $0.localDate.adding(days: 1).startOfDay }
                .filter { $0 > date }
        )

        return [date] + transitionDates.sorted()
    }

    func suggestedReloadDate(after date: Date) -> Date {
        let fallback = date.addingTimeInterval(6 * 60 * 60)
        guard let lastTransition = timelineDates(startingAt: date).last,
              lastTransition > date else {
            return fallback
        }
        return max(lastTransition.addingTimeInterval(60 * 60), fallback)
    }
}

struct WidgetCollectionOccurrence: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let localDate: WidgetLocalDate
    let containers: [WidgetContainer]

    init(id: String, localDate: WidgetLocalDate, containers: [WidgetContainer]) {
        self.id = id
        self.localDate = localDate
        self.containers = containers
    }

    var summary: WidgetCollectionSummary {
        WidgetCollectionSummary.make(for: containers)
    }
}

struct WidgetContainer: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let symbolName: String

    init(id: String, name: String, symbolName: String) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
    }
}

struct WidgetLocalDate: Codable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    static let timeZone: TimeZone = {
        guard let timeZone = TimeZone(identifier: "Europe/London") else {
            preconditionFailure("Europe/London must be present in the system time-zone database")
        }
        return timeZone
    }()

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_GB")
        calendar.timeZone = timeZone
        return calendar
    }

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date) {
        let components = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            preconditionFailure("Gregorian calendar must produce date components")
        }
        self.init(year: year, month: month, day: day)
    }

    var dateAtNoon: Date {
        date(hour: 12)
    }

    var startOfDay: Date {
        date(hour: 0)
    }

    var fullDescription: String {
        dateAtNoon.formatted(
            Date.FormatStyle(
                date: .complete,
                time: .omitted,
                locale: Locale(identifier: "en_GB"),
                calendar: Self.calendar,
                timeZone: Self.timeZone
            )
        )
    }

    var conciseDescription: String {
        dateAtNoon.formatted(
            Date.FormatStyle(
                date: .abbreviated,
                time: .omitted,
                locale: Locale(identifier: "en_GB"),
                calendar: Self.calendar,
                timeZone: Self.timeZone
            )
        )
    }

    var shortOrdinalDescription: String {
        let weekdayIndex = Self.calendar.component(.weekday, from: dateAtNoon) - 1
        let weekday = Self.calendar.shortWeekdaySymbols[weekdayIndex]
        return "\(weekday) \(day)\(Self.ordinalSuffix(for: day))"
    }

    func adding(days: Int) -> WidgetLocalDate {
        guard let date = Self.calendar.date(byAdding: .day, value: days, to: dateAtNoon) else {
            preconditionFailure("Gregorian date arithmetic failed")
        }
        return WidgetLocalDate(date: date)
    }

    static func < (lhs: WidgetLocalDate, rhs: WidgetLocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func ordinalSuffix(for day: Int) -> String {
        if (11...13).contains(day % 100) {
            return "th"
        }

        switch day % 10 {
        case 1: return "st"
        case 2: return "nd"
        case 3: return "rd"
        default: return "th"
        }
    }

    private func date(hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour

        guard let date = Self.calendar.date(from: components) else {
            preconditionFailure("A validated widget date must produce a local time")
        }
        return date
    }
}

enum WidgetSchedulePresentation: Equatable, Sendable {
    case notConfigured
    case empty(propertyDisplayName: String, fetchedAt: Date?)
    case scheduled(
        propertyDisplayName: String,
        occurrence: WidgetCollectionOccurrence,
        fetchedAt: Date?,
        isStale: Bool
    )

    var accessibilitySummary: String {
        switch self {
        case .notConfigured:
            return "Set up Bins Out to see your next scheduled collection."
        case let .empty(propertyDisplayName, _):
            return "\(propertyDisplayName). No upcoming scheduled collections are saved."
        case let .scheduled(propertyDisplayName, occurrence, _, isStale):
            let freshness = isStale ? " The saved schedule may be out of date." : ""
            return "\(propertyDisplayName). Next scheduled collection: \(occurrence.summary.title), \(occurrence.localDate.fullDescription). Containers: \(occurrence.containers.map(\.name).joined(separator: ", ")).\(freshness)"
        }
    }
}

struct WidgetCollectionSummary: Equatable, Sendable {
    let title: String
    let symbolName: String
    let backgroundStyle: WidgetCollectionBackgroundStyle

    static func make(for containers: [WidgetContainer]) -> WidgetCollectionSummary {
        let labels = containers.map { $0.name.lowercased() }
        let hasGeneralWaste = labels.contains { label in
            label.contains("general waste")
                || label.contains("household waste")
                || label.contains("wheelie bin")
                || label.contains("rubbish")
                || label.contains("refuse")
        }
        let hasRecycling = labels.contains { label in
            label.contains("recycling")
                || label.contains("blue bag")
                || label.contains("black box")
                || label.contains("green box")
        }
        let hasGardenWaste = labels.contains { $0.contains("garden") }
        let hasFoodWaste = labels.contains { $0.contains("food waste") || $0.contains("food bin") }

        if hasGeneralWaste && hasRecycling {
            return WidgetCollectionSummary(
                title: "Bins + Recycling",
                symbolName: "trash.fill",
                backgroundStyle: .bins
            )
        }
        if hasGeneralWaste && hasFoodWaste {
            return WidgetCollectionSummary(
                title: "Bins + Food",
                symbolName: "trash.fill",
                backgroundStyle: .bins
            )
        }
        if hasRecycling {
            return WidgetCollectionSummary(
                title: "Recycling",
                symbolName: "arrow.3.trianglepath",
                backgroundStyle: .recycling
            )
        }
        if hasGeneralWaste {
            return WidgetCollectionSummary(
                title: "Bins",
                symbolName: "trash.fill",
                backgroundStyle: .bins
            )
        }
        if hasGardenWaste {
            return WidgetCollectionSummary(
                title: "Garden waste",
                symbolName: "leaf.fill",
                backgroundStyle: .garden
            )
        }
        if hasFoodWaste {
            return WidgetCollectionSummary(
                title: "Food waste",
                symbolName: "fork.knife",
                backgroundStyle: .food
            )
        }
        return WidgetCollectionSummary(
            title: containers.count == 1 ? containers[0].name : "Collection",
            symbolName: containers.first?.symbolName ?? "calendar",
            backgroundStyle: .neutral
        )
    }
}

enum WidgetCollectionBackgroundStyle: Equatable, Sendable {
    case recycling
    case bins
    case garden
    case food
    case neutral
}
