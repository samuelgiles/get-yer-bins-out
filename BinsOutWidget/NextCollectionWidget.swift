import SwiftUI
import WidgetKit

struct NextCollectionWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: BinsOutCollectionWidget.kind, provider: NextCollectionTimelineProvider()) { entry in
            NextCollectionWidgetView(entry: entry)
                .widgetURL(BinsOutCollectionWidget.collectionURL)
        }
        .configurationDisplayName("Next collection")
        .description("See what goes out next for your saved property.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct NextCollectionTimelineProvider: TimelineProvider {
    private let store: any WidgetPayloadStoring

    init(store: any WidgetPayloadStoring = FileWidgetPayloadStore()) {
        self.store = store
    }

    func placeholder(in context: Context) -> NextCollectionWidgetEntry {
        NextCollectionWidgetEntry(date: .now, payload: .placeholder)
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping @Sendable (NextCollectionWidgetEntry) -> Void
    ) {
        let store = store
        let isPreview = context.isPreview
        Task {
            completion(
                NextCollectionWidgetEntry(
                    date: .now,
                    payload: await Self.payloadForWidget(store: store, isPreview: isPreview)
                )
            )
        }
    }

    func getTimeline(
        in context: Context,
        completion: @escaping @Sendable (Timeline<NextCollectionWidgetEntry>) -> Void
    ) {
        let store = store
        let isPreview = context.isPreview
        Task {
            let now = Date.now
            let payload = await Self.payloadForWidget(store: store, isPreview: isPreview)
            let entries = payload.timelineDates(startingAt: now).map {
                NextCollectionWidgetEntry(date: $0, payload: payload)
            }
            completion(
                Timeline(
                    entries: entries,
                    policy: .after(payload.suggestedReloadDate(after: now))
                )
            )
        }
    }

    private static func payloadForWidget(
        store: any WidgetPayloadStoring,
        isPreview: Bool
    ) async -> WidgetSchedulePayload {
        if isPreview {
            return .placeholder
        }
        return (try? await store.load()) ?? .empty
    }
}

struct NextCollectionWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetSchedulePayload

    var presentation: WidgetSchedulePresentation {
        payload.presentation(at: date)
    }
}

private struct NextCollectionWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: NextCollectionWidgetEntry

    var body: some View {
        Group {
            switch entry.presentation {
            case .notConfigured:
                WidgetUnavailableView(
                    title: "Set up Bins Out",
                    detail: "Add a property to see scheduled collections.",
                    symbolName: "house"
                )
            case let .empty(propertyDisplayName, fetchedAt):
                WidgetUnavailableView(
                    title: "No saved dates",
                    detail: freshnessText(fetchedAt: fetchedAt, isStale: false),
                    symbolName: "calendar.badge.exclamationmark",
                    propertyDisplayName: propertyDisplayName
                )
            case let .scheduled(propertyDisplayName, occurrence, fetchedAt, isStale):
                switch family {
                case .systemMedium:
                    MediumCollectionWidgetView(
                        propertyDisplayName: propertyDisplayName,
                        occurrence: occurrence,
                        freshness: freshnessText(fetchedAt: fetchedAt, isStale: isStale),
                        isStale: isStale
                    )
                default:
                    SmallCollectionWidgetView(
                        propertyDisplayName: propertyDisplayName,
                        occurrence: occurrence,
                        freshness: freshnessText(fetchedAt: fetchedAt, isStale: isStale),
                        isStale: isStale
                    )
                }
            }
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.presentation.accessibilitySummary)
    }

    private func freshnessText(fetchedAt: Date?, isStale: Bool) -> String {
        guard let fetchedAt else {
            return isStale ? "Schedule needs updating" : "No saved update yet"
        }
        let updated = "Updated \(fetchedAt.formatted(date: .abbreviated, time: .omitted))"
        return isStale ? "\(updated) · needs updating" : updated
    }
}

private struct SmallCollectionWidgetView: View {
    let propertyDisplayName: String
    let occurrence: WidgetCollectionOccurrence
    let freshness: String
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetPropertyHeading(propertyDisplayName: propertyDisplayName)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: occurrence.summary.symbolName)
                    .font(.headline.weight(.semibold))
                    .widgetAccentable()
                    .accessibilityHidden(true)
                Text(occurrence.summary.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Text(occurrence.localDate.conciseDescription)
                .font(.title3.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(containerText(limit: 1))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 0)

            WidgetFreshnessLabel(text: freshness, isStale: isStale)
        }
    }

    private func containerText(limit: Int) -> String {
        let visible = occurrence.containers.prefix(limit).map(\.name)
        let more = occurrence.containers.count - visible.count
        return more > 0 ? "\(visible.joined(separator: ", ")) +\(more)" : visible.joined(separator: ", ")
    }
}

private struct MediumCollectionWidgetView: View {
    let propertyDisplayName: String
    let occurrence: WidgetCollectionOccurrence
    let freshness: String
    let isStale: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                WidgetPropertyHeading(propertyDisplayName: propertyDisplayName)

                Label("Next scheduled collection", systemImage: "calendar")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(occurrence.localDate.fullDescription)
                    .font(.headline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 6) {
                    Image(systemName: occurrence.summary.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .widgetAccentable()
                        .accessibilityHidden(true)
                    Text(occurrence.summary.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
                WidgetFreshnessLabel(text: freshness, isStale: isStale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                Text("Put out")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                ForEach(occurrence.containers.prefix(3)) { container in
                    Label(container.name, systemImage: container.symbolName)
                        .font(.caption)
                        .lineLimit(1)
                }

                if occurrence.containers.count > 3 {
                    Text("+ \(occurrence.containers.count - 3) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WidgetPropertyHeading: View {
    let propertyDisplayName: String

    var body: some View {
        Label(propertyDisplayName, systemImage: "house.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
}

private struct WidgetFreshnessLabel: View {
    let text: String
    let isStale: Bool

    var body: some View {
        Label(text, systemImage: isStale ? "arrow.triangle.2.circlepath" : "clock")
            .font(.caption2)
            .foregroundStyle(isStale ? .secondary : .tertiary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
    }
}

private struct WidgetUnavailableView: View {
    let title: String
    let detail: String
    let symbolName: String
    var propertyDisplayName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let propertyDisplayName {
                WidgetPropertyHeading(propertyDisplayName: propertyDisplayName)
            }
            Image(systemName: symbolName)
                .font(.title2)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text(title)
                .font(.headline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
            Spacer(minLength: 0)
            Text("Open Bins Out")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private extension WidgetSchedulePayload {
    static let placeholder = WidgetSchedulePayload(
        propertyDisplayName: "Home",
        occurrences: [
            WidgetCollectionOccurrence(
                id: "preview-collection",
                localDate: WidgetLocalDate(year: 2026, month: 8, day: 21),
                containers: [
                    WidgetContainer(id: "general", name: "Black wheelie bin", symbolName: "trash.fill"),
                    WidgetContainer(id: "green", name: "Green recycling box", symbolName: "arrow.3.trianglepath"),
                    WidgetContainer(id: "food", name: "Food waste bin", symbolName: "fork.knife"),
                ]
            ),
        ],
        fetchedAt: Date(timeIntervalSince1970: 1_786_867_200),
        hasRefreshIssue: false
    )
}

#if DEBUG
#Preview("Small — scheduled", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    NextCollectionWidgetEntry(
        date: Date(timeIntervalSince1970: 1_786_780_800),
        payload: .placeholder
    )
}

#Preview("Medium — scheduled", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    NextCollectionWidgetEntry(
        date: Date(timeIntervalSince1970: 1_786_780_800),
        payload: .placeholder
    )
}

#Preview("Small — stale", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    NextCollectionWidgetEntry(
        date: Date(timeIntervalSince1970: 1_786_780_800),
        payload: WidgetSchedulePayload(
            propertyDisplayName: WidgetSchedulePayload.placeholder.propertyDisplayName,
            occurrences: WidgetSchedulePayload.placeholder.occurrences,
            fetchedAt: WidgetSchedulePayload.placeholder.fetchedAt,
            hasRefreshIssue: true
        )
    )
}

#Preview("Medium — empty", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    NextCollectionWidgetEntry(
        date: Date(timeIntervalSince1970: 1_786_780_800),
        payload: WidgetSchedulePayload(
            propertyDisplayName: "Home",
            occurrences: [],
            fetchedAt: Date(timeIntervalSince1970: 1_786_867_200),
            hasRefreshIssue: false
        )
    )
}
#endif
