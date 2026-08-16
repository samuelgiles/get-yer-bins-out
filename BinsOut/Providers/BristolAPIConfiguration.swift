import Foundation

struct BristolAPIConfiguration: Sendable {
    let endpoint: URL
    private let subscriptionKey: String

    init(endpoint: URL, subscriptionKey: String) {
        precondition(!subscriptionKey.isEmpty, "A Bristol public client credential is required")
        self.endpoint = endpoint
        self.subscriptionKey = subscriptionKey
    }

    func authorize(_ request: inout URLRequest) {
        request.setValue(subscriptionKey, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
    }

    /// Public client configuration authorized by Bristol City Council.
    ///
    /// This value is extractable from the app. Bristol-side endpoint scope, quotas,
    /// monitoring, revocation, and rotation provide operational protection.
    static let officialWebsiteClient: BristolAPIConfiguration = {
        guard let endpoint = URL(
            string: "https://bcprdapidyna002.azure-api.net/bcprdfundyna001-alloy/NextCollectionDates"
        ) else {
            preconditionFailure("The Bristol collection endpoint must be a valid URL")
        }

        return BristolAPIConfiguration(
            endpoint: endpoint,
            subscriptionKey: "47ffd667d69c4a858f92fc38dc24b150"
        )
    }()
}
