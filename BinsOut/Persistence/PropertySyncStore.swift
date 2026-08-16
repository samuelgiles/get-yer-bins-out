import Foundation
import Security

struct SyncedPropertyRecord: Codable, Equatable, Sendable {
    let property: Property
    let updatedAt: Date
}

protocol PropertySyncing: Sendable {
    func load() async throws -> SyncedPropertyRecord?
    func save(_ record: SyncedPropertyRecord) async throws
}

struct NoopPropertySyncStore: PropertySyncing {
    func load() async throws -> SyncedPropertyRecord? { nil }
    func save(_ record: SyncedPropertyRecord) async throws { }
}

enum PropertySyncError: Error, LocalizedError, Sendable {
    case keychain(OSStatus)
    case invalidData

    var errorDescription: String? {
        switch self {
        case .keychain:
            "iCloud Keychain property sync is temporarily unavailable."
        case .invalidData:
            "The property stored in iCloud Keychain could not be read."
        }
    }
}

actor KeychainPropertySyncStore: PropertySyncing {
    private let service: String
    private let account: String

    init(
        service: String = "com.samuelgiles.BinsOut.property-sync",
        account: String = "selected-property"
    ) {
        self.service = service
        self.account = account
    }

    func load() async throws -> SyncedPropertyRecord? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnData as String: true,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw PropertySyncError.keychain(status)
        }
        guard let data = result as? Data else {
            throw PropertySyncError.invalidData
        }
        do {
            return try JSONDecoder().decode(SyncedPropertyRecord.self, from: data)
        } catch {
            throw PropertySyncError.invalidData
        }
    }

    func save(_ record: SyncedPropertyRecord) async throws {
        let encoded = try JSONEncoder().encode(record)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
        ]
        let update: [String: Any] = [kSecValueData as String: encoded]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw PropertySyncError.keychain(updateStatus)
        }

        var newItem = query
        newItem[kSecValueData as String] = encoded
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw PropertySyncError.keychain(addStatus)
        }
    }
}
