import Foundation

struct BristolCollectionProvider: CollectionProvider {
    let identifier = "bristol-next-collection-dates"
    let displayName = "Bristol City Council"

    private let session: URLSession
    private let configuration: BristolAPIConfiguration
    private let now: @Sendable () -> Date

    init(
        session: URLSession = .shared,
        configuration: BristolAPIConfiguration = .officialWebsiteClient,
        now: @escaping @Sendable () -> Date = { Date.now }
    ) {
        self.session = session
        self.configuration = configuration
        self.now = now
    }

    func schedule(for property: Property) async throws -> ScheduleSnapshot {
        guard property.council == .bristolCityCouncil else {
            throw CollectionProviderError.unsupportedCouncil
        }

        let uprn = try UPRNValidator.validated(property.uprn)
        var request = URLRequest(url: configuration.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        configuration.authorize(&request)
        request.httpBody = try JSONEncoder().encode(BristolRequestDTO(uprn: uprn))

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CollectionProviderError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw CollectionProviderError.unauthorized
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw CollectionProviderError.httpStatus(httpResponse.statusCode)
        }

        let responseDTO: BristolResponseDTO
        do {
            responseDTO = try JSONDecoder().decode(BristolResponseDTO.self, from: data)
        } catch {
            throw CollectionProviderError.malformedResponse
        }

        if let status = responseDTO.status, status.caseInsensitiveCompare("OK") != .orderedSame {
            throw CollectionProviderError.apiResponse(responseDTO.error?.description ?? status)
        }

        let result = map(responseDTO.data ?? [])
        guard !result.containers.isEmpty else {
            if result.hadMalformedDate {
                throw CollectionProviderError.malformedResponse
            }
            throw CollectionProviderError.noCollections
        }

        let fetchedAt = now()
        let snapshot = ScheduleNormalizer.snapshot(
            property: property,
            providerIdentifier: identifier,
            providerDisplayName: displayName,
            fetchedAt: fetchedAt,
            containers: result.containers
        )
        guard !snapshot.occurrences.isEmpty else {
            throw CollectionProviderError.noCollections
        }
        return snapshot
    }

    private func map(_ data: [BristolContainerDTO]) -> (containers: [ProviderContainerSchedule], hadMalformedDate: Bool) {
        var containers: [ProviderContainerSchedule] = []
        var hadMalformedDate = false

        for containerDTO in data {
            let trimmedLabel = containerDTO.containerName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let label = (trimmedLabel?.isEmpty == false) ? trimmedLabel ?? "Unknown container" : "Unknown container"
            let sourceID = containerDTO.containerID?.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedID = (sourceID?.isEmpty == false) ? sourceID ?? fallbackID(label: label) : fallbackID(label: label)
            var dates: [LocalDate] = []

            for collectionDTO in containerDTO.collections {
                guard let dateValue = collectionDTO.dateValue else {
                    hadMalformedDate = true
                    continue
                }
                do {
                    dates.append(try LocalDate(iso8601Timestamp: dateValue))
                } catch {
                    hadMalformedDate = true
                }
            }

            if !dates.isEmpty {
                containers.append(ProviderContainerSchedule(sourceID: resolvedID, sourceLabel: label, dates: dates))
            }
        }

        return (containers, hadMalformedDate)
    }

    private func fallbackID(label: String) -> String {
        let encodedLabel = label
            .lowercased()
            .utf8
            .map { String($0, radix: 16) }
            .joined(separator: "-")
        return "label-\(encodedLabel)"
    }
}

private struct BristolRequestDTO: Encodable {
    let uprn: String
}
