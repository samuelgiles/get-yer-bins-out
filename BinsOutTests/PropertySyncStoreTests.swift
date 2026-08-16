import Security
import XCTest
@testable import BinsOut

final class PropertySyncStoreTests: XCTestCase {
    func testSynchronizableKeychainStoreRoundTripsPropertyRecord() async throws {
        let service = "com.samuelgiles.BinsOut.tests.\(UUID().uuidString)"
        let account = "selected-property"
        defer { deleteTestItem(service: service, account: account) }

        let store = KeychainPropertySyncStore(service: service, account: account)
        let record = SyncedPropertyRecord(
            property: Property(
                id: UUID(uuidString: "CA5E0000-0000-4000-8000-000000000005")!,
                council: .bristolCityCouncil,
                uprn: "001234567890",
                displayName: "Test home"
            ),
            updatedAt: Date(timeIntervalSince1970: 1_786_867_200)
        )

        try await store.save(record)

        let loaded = try await store.load()
        XCTAssertEqual(loaded, record)
    }

    private func deleteTestItem(service: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
