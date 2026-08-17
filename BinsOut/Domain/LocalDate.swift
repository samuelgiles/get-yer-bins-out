import Foundation

enum LocalDateError: Error, Equatable, LocalizedError, Sendable {
    case invalidComponents
    case invalidProviderDate(String)

    var errorDescription: String? {
        switch self {
        case .invalidComponents:
            "The collection date is not valid."
        case .invalidProviderDate:
            "The collection service returned a date in an unsupported format."
        }
    }
}

struct LocalDate: Codable, Hashable, Comparable, Sendable {
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

    init(year: Int, month: Int, day: Int) throws(LocalDateError) {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        guard let date = Self.calendar.date(from: components) else {
            throw .invalidComponents
        }

        let roundTrip = Self.calendar.dateComponents([.year, .month, .day], from: date)
        guard roundTrip.year == year, roundTrip.month == month, roundTrip.day == day else {
            throw .invalidComponents
        }

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

        self.year = year
        self.month = month
        self.day = day
    }

    init(iso8601Timestamp: String) throws(LocalDateError) {
        let datePart = String(iso8601Timestamp.prefix(10))
        let parts = datePart.split(separator: "-", omittingEmptySubsequences: false)

        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            throw .invalidProviderDate(iso8601Timestamp)
        }

        do {
            try self.init(year: year, month: month, day: day)
        } catch {
            throw .invalidProviderDate(iso8601Timestamp)
        }
    }

    var rawValue: String {
        "\(year)-\(Self.twoDigits(month))-\(Self.twoDigits(day))"
    }

    var dateAtNoon: Date {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12

        guard let date = Self.calendar.date(from: components) else {
            preconditionFailure("A validated LocalDate must convert back into a Date")
        }
        return date
    }

    func date(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        guard let date = Self.calendar.date(from: components) else {
            preconditionFailure("A validated LocalDate must produce a local time")
        }
        return date
    }

    func adding(days: Int) -> LocalDate {
        guard let date = Self.calendar.date(byAdding: .day, value: days, to: dateAtNoon) else {
            preconditionFailure("Gregorian date arithmetic failed")
        }
        return LocalDate(date: date)
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

    var weekdayName: String {
        let weekdayIndex = Self.calendar.component(.weekday, from: dateAtNoon) - 1
        return Self.calendar.weekdaySymbols[weekdayIndex]
    }

    var shortDescription: String {
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

    static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
