import Foundation
import XCTest
@testable import BinsOut

/// Temporary documentation helper: writes deterministic, synthetic App Group
/// files so README screenshots can be captured without a live Bristol request.
/// Skipped unless BINS_OUT_EXPORT_FIXTURE_DIR is supplied locally.
final class ScreenshotFixtureExporterTests: XCTestCase {
    func testExportScreenshotFixture() throws {
        guard ProcessInfo.processInfo.environment["BINS_OUT_EXPORT_FIXTURE"] == "1" else {
            throw XCTSkip("Set BINS_OUT_EXPORT_FIXTURE=1 to export screenshot fixtures.")
        }

        let url = AppGroupConfiguration.containerURL()
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        print("SCREENSHOT_FIXTURE_DIR=\(url.path())")
        let property = Property(
            id: UUID(uuidString: "5C0E0000-0000-4000-8000-000000000001")!,
            council: .bristolCityCouncil,
            uprn: "000000000001",
            displayName: "99 The Mall, Clifton"
        )

        let fetchedAt = Date(timeIntervalSince1970: 1_786_863_600)
        let occurrences = [
            occurrence(property: property, month: 8, day: 18, containers: [
                ("fixture-black-recycling-box", "Black recycling box"),
                ("fixture-green-recycling-box", "Green recycling box"),
                ("fixture-food-bin", "Brown food bin"),
            ]),
            occurrence(property: property, month: 8, day: 25, containers: [
                ("fixture-general-waste", "Black wheelie bin"),
                ("fixture-food-bin", "Brown food bin"),
            ]),
            occurrence(property: property, month: 9, day: 1, containers: [
                ("fixture-black-recycling-box", "Black recycling box"),
                ("fixture-green-recycling-box", "Green recycling box"),
                ("fixture-food-bin", "Brown food bin"),
            ]),
            occurrence(property: property, month: 9, day: 8, containers: [
                ("fixture-general-waste", "Black wheelie bin"),
                ("fixture-food-bin", "Brown food bin"),
            ]),
        ]

        let snapshot = ScheduleSnapshot(
            propertyID: property.id,
            occurrences: occurrences,
            providerIdentifier: "fixture",
            providerDisplayName: "Sample schedule",
            fetchedAt: fetchedAt
        )

        var settings = UserSettings()
        settings.reminders.notificationsEnabled = true
        settings.reminders.liveActivitiesEnabled = true

        let appData = PersistedAppData(
            property: property,
            snapshot: snapshot,
            propertyUpdatedAt: fetchedAt,
            settings: settings
        )

        let payload = WidgetSchedulePayload(
            propertyDisplayName: property.displayName,
            occurrences: occurrences.map { occurrence in
                WidgetCollectionOccurrence(
                    id: occurrence.id,
                    localDate: WidgetLocalDate(
                        year: occurrence.localDate.year,
                        month: occurrence.localDate.month,
                        day: occurrence.localDate.day
                    ),
                    containers: occurrence.containers.map { container in
                        WidgetContainer(
                            id: container.sourceID,
                            name: container.sourceLabel,
                            symbolName: container.displayMetadata.symbolName
                        )
                    }
                )
            },
            fetchedAt: fetchedAt,
            hasRefreshIssue: false
        )

        let encoder = JSONEncoder()
        try encoder.encode(appData)
            .write(to: url.appending(path: "app-data.json"), options: .atomic)
        try encoder.encode(payload)
            .write(to: url.appending(path: "widget-schedule.json"), options: .atomic)
    }

    private func occurrence(
        property: Property,
        month: Int,
        day: Int,
        containers: [(String, String)]
    ) -> CollectionOccurrence {
        CollectionOccurrence(
            propertyID: property.id,
            localDate: try! LocalDate(year: 2026, month: month, day: day),
            containers: containers.map { ContainerKind(sourceID: $0.0, sourceLabel: $0.1) }
        )
    }
}
