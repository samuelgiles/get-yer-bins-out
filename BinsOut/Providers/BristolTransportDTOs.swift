import Foundation

struct BristolResponseDTO: Decodable {
    let status: String?
    let data: [BristolContainerDTO]?
    let error: BristolJSONValue?

    private enum CodingKeys: String, CodingKey {
        case status
        case data
        case error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decodeIfPresent(LossyString.self, forKey: .status)?.value
        data = try container.decodeIfPresent([BristolContainerDTO].self, forKey: .data)
        error = try container.decodeIfPresent(BristolJSONValue.self, forKey: .error)
    }
}

struct BristolContainerDTO: Decodable {
    let containerID: String?
    let containerName: String?
    let collections: [BristolCollectionDTO]

    private enum CodingKeys: String, CodingKey {
        case containerID
        case containerName
        case collections = "collection"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        containerID = try container.decodeIfPresent(LossyString.self, forKey: .containerID)?.value
        containerName = try container.decodeIfPresent(String.self, forKey: .containerName)
        collections = try container.decodeIfPresent([BristolCollectionDTO].self, forKey: .collections) ?? []
    }
}

struct BristolCollectionDTO: Decodable {
    let dateValue: String?

    private enum CodingKeys: String, CodingKey {
        case nextCollectionDate
        case collectionDate
        case date
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateValue = try container.decodeIfPresent(String.self, forKey: .nextCollectionDate)
            ?? container.decodeIfPresent(String.self, forKey: .collectionDate)
            ?? container.decodeIfPresent(String.self, forKey: .date)
    }
}

struct LossyString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let integer = try? container.decode(Int64.self) {
            value = String(integer)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected a string or integer")
            )
        }
    }
}

enum BristolJSONValue: Decodable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case boolean(Bool)
    case object([String: BristolJSONValue])
    case array([BristolJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let boolean = try? container.decode(Bool.self) {
            self = .boolean(boolean)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else if let object = try? container.decode([String: BristolJSONValue].self) {
            self = .object(object)
        } else if let array = try? container.decode([BristolJSONValue].self) {
            self = .array(array)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    var description: String {
        switch self {
        case .string(let value):
            value
        case .number(let value):
            value.formatted()
        case .boolean(let value):
            value.description
        case .object:
            "The collection service reported an error."
        case .array:
            "The collection service reported an error."
        case .null:
            ""
        }
    }
}

