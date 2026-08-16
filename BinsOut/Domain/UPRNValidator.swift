import Foundation

enum UPRNValidationError: Error, Equatable, LocalizedError, Sendable {
    case empty
    case nonNumeric
    case tooLong

    var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a UPRN."
        case .nonNumeric:
            "A UPRN can contain numbers only."
        case .tooLong:
            "A UPRN can be no more than 12 digits."
        }
    }
}

enum UPRNValidator {
    static func validated(_ value: String) throws(UPRNValidationError) -> String {
        guard !value.isEmpty else {
            throw .empty
        }

        guard value.count <= 12 else {
            throw .tooLong
        }

        guard value.unicodeScalars.allSatisfy({ CharacterSet.decimalDigits.contains($0) && $0.isASCII }) else {
            throw .nonNumeric
        }

        return value
    }
}

