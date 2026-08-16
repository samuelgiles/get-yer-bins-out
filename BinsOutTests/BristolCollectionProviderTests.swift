import XCTest
@testable import BinsOut

final class BristolCollectionProviderTests: XCTestCase {
    private let property = Property(
        id: UUID(uuidString: "B1570100-0000-4000-8000-000000000001")!,
        council: .bristolCityCouncil,
        uprn: "001234567890",
        displayName: "Test property"
    )

    override func tearDown() {
        URLProtocolStub.handler = nil
        super.tearDown()
    }

    func testDecodesAllDatesAndPreservesUnknownContainer() async throws {
        let json = #"""
        {
          "status": "OK",
          "data": [
            {
              "containerID": "known-1",
              "containerName": "Green recycling box",
              "collection": [
                {"nextCollectionDate": "2026-08-21T00:00:00"},
                {"nextCollectionDate": "2026-08-28T00:00:00"}
              ],
              "futureField": "ignored"
            },
            {
              "containerID": 42,
              "containerName": "Future purple pod",
              "collection": [
                {"nextCollectionDate": "2026-08-21T00:00:00"}
              ]
            }
          ]
        }
        """#
        let provider = makeProvider(body: Data(json.utf8))

        let snapshot = try await provider.schedule(for: property)

        XCTAssertEqual(snapshot.occurrences.count, 2)
        XCTAssertEqual(snapshot.occurrences[0].containers.count, 2)
        let unknown = try XCTUnwrap(snapshot.occurrences[0].containers.first(where: { $0.sourceID == "42" }))
        XCTAssertEqual(unknown.sourceLabel, "Future purple pod")
        XCTAssertEqual(unknown.displayMetadata.colorRole, .unknown)
    }

    func testPostsExactUnpaddedUPRNAndCredentialHeader() async throws {
        let json = #"{"status":"OK","data":[{"containerID":"food","containerName":"Brown food bin","collection":[{"nextCollectionDate":"2026-08-21T00:00:00"}]}]}"#
        URLProtocolStub.handler = { request in
            XCTAssertEqual(request.value(forHTTPHeaderField: "Ocp-Apim-Subscription-Key"), "unit-test-credential")
            let body = try Self.bodyData(from: request)
            let payload = try JSONSerialization.jsonObject(with: body) as? [String: String]
            XCTAssertEqual(payload?["uprn"], "001234567890")
            return Self.response(statusCode: 200, data: Data(json.utf8))
        }
        let provider = makeProvider()

        _ = try await provider.schedule(for: property)
    }

    func testThrowsForAPIErrorPayload() async {
        let json = #"{"status":"ERROR","data":[],"error":"No property found"}"#
        let provider = makeProvider(body: Data(json.utf8))

        await assertError(.apiResponse("No property found")) {
            _ = try await provider.schedule(for: property)
        }
    }

    func testThrowsForEmptySchedule() async {
        let json = #"{"status":"OK","data":[]}"#
        let provider = makeProvider(body: Data(json.utf8))

        await assertError(.noCollections) {
            _ = try await provider.schedule(for: property)
        }
    }

    func testThrowsForMalformedJSON() async {
        let provider = makeProvider(body: Data("not-json".utf8))

        await assertError(.malformedResponse) {
            _ = try await provider.schedule(for: property)
        }
    }

    func testThrowsWhenEveryCollectionDateIsMalformed() async {
        let json = #"{"status":"OK","data":[{"containerID":"food","containerName":"Brown food bin","collection":[{"nextCollectionDate":"not-a-date"}]}]}"#
        let provider = makeProvider(body: Data(json.utf8))

        await assertError(.malformedResponse) {
            _ = try await provider.schedule(for: property)
        }
    }

    func testThrowsForHTTPFailure() async {
        let provider = makeProvider(statusCode: 503, body: Data())

        await assertError(.httpStatus(503)) {
            _ = try await provider.schedule(for: property)
        }
    }

    private func makeProvider(statusCode: Int = 200, body: Data? = nil) -> BristolCollectionProvider {
        if let body {
            URLProtocolStub.handler = { _ in
                Self.response(statusCode: statusCode, data: body)
            }
        }

        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: sessionConfiguration)
        guard let endpoint = URL(string: "https://example.invalid/collections") else {
            preconditionFailure("Static test configuration must be valid")
        }
        let apiConfiguration = BristolAPIConfiguration(
            endpoint: endpoint,
            subscriptionKey: "unit-test-credential"
        )
        return BristolCollectionProvider(
            session: session,
            configuration: apiConfiguration,
            now: { Date(timeIntervalSince1970: 1_786_867_200) }
        )
    }

    private static func response(statusCode: Int, data: Data) -> (HTTPURLResponse, Data) {
        guard let url = URL(string: "https://example.invalid/collections"),
              let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil) else {
            preconditionFailure("Static test URL must be valid")
        }
        return (response, data)
    }

    private static func bodyData(from request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            throw URLError(.cannotDecodeRawData)
        }

        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while true {
            let readCount = stream.read(&buffer, maxLength: buffer.count)
            if readCount < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeRawData)
            }
            if readCount == 0 {
                return result
            }
            result.append(contentsOf: buffer.prefix(readCount))
        }
    }

    private func assertError(
        _ expected: CollectionProviderError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expected)")
        } catch let error as CollectionProviderError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() { }
}
