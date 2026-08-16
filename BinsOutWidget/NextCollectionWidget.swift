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
            case let .scheduled(propertyDisplayName, occurrence, _, isStale):
                let countdown = occurrence.localDate.countdownDescription(relativeTo: entry.date)
                switch family {
                case .systemMedium:
                    MediumCollectionWidgetView(
                        propertyDisplayName: propertyDisplayName,
                        occurrence: occurrence,
                        countdown: countdown,
                        isStale: isStale
                    )
                default:
                    SmallCollectionWidgetView(
                        propertyDisplayName: propertyDisplayName,
                        occurrence: occurrence,
                        countdown: countdown,
                        isStale: isStale
                    )
                }
            }
        }
        .containerBackground(for: .widget) {
            widgetBackground
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(entry.presentation.accessibilitySummary(relativeTo: entry.date))
    }

    @ViewBuilder
    private var widgetBackground: some View {
        switch entry.presentation {
        case let .scheduled(_, occurrence, _, _):
            occurrence.summary.backgroundStyle.color
        case .notConfigured, .empty:
            Color.clear
        }
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
    let countdown: String
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            WidgetPropertyHeading(propertyDisplayName: propertyDisplayName, onColoredBackground: true)

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
            .foregroundStyle(.white)

            Text(occurrence.localDate.shortOrdinalDescription)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            WidgetCountdownLabel(text: countdown, isStale: isStale)
        }
    }
}

private struct MediumCollectionWidgetView: View {
    let propertyDisplayName: String
    let occurrence: WidgetCollectionOccurrence
    let countdown: String
    let isStale: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                WidgetPropertyHeading(propertyDisplayName: propertyDisplayName, onColoredBackground: true)

                HStack(spacing: 6) {
                    Image(systemName: occurrence.summary.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .widgetAccentable()
                        .accessibilityHidden(true)
                    Text(occurrence.summary.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)

                Text(occurrence.localDate.shortOrdinalDescription)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                WidgetCountdownLabel(text: countdown, isStale: isStale)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text("Put out")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.78))

                ForEach(occurrence.containers) { container in
                    Label(container.name, systemImage: container.symbolName)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct WidgetPropertyHeading: View {
    let propertyDisplayName: String
    var onColoredBackground = false

    var body: some View {
        Label(propertyDisplayName, systemImage: "house.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(onColoredBackground ? .white.opacity(0.78) : .secondary)
            .lineLimit(1)
    }
}

private struct WidgetCountdownLabel: View {
    let text: String
    let isStale: Bool

    var body: some View {
        HStack(spacing: 5) {
            Text(text)
                .font(.subheadline.weight(.semibold))
            if isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
        }
        .foregroundStyle(.white.opacity(isStale ? 0.92 : 0.78))
        .lineLimit(1)
        .minimumScaleFactor(0.82)
    }
}

private extension WidgetCollectionBackgroundStyle {
    var color: Color {
        switch self {
        case .recycling:
            Color(red: 0.03, green: 0.40, blue: 0.22)
        case .bins:
            Color.black
        case .garden:
            Color(red: 0.08, green: 0.36, blue: 0.20)
        case .food:
            Color.brown
        case .neutral:
            Color.teal
        }
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
        propertyDisplayName: "Preview residence",
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
#Preview("Small — Recycling only (green background)", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.recyclingOnly)
}

#Preview("Medium — Recycling only (green background)", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.recyclingOnly)
}

#Preview("Small — Wheelie bin and recycling (black background)", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.wheelieBinMixed)
}

#Preview("Medium — Wheelie bin and recycling (complete Put out list)", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.wheelieBinMixed)
}

#Preview("Small — Garden waste", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.gardenWaste)
}

#Preview("Medium — Garden waste", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.gardenWaste)
}

#Preview("Small — Stale recycling", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.staleRecycling)
}

#Preview("Medium — Stale recycling", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.staleRecycling)
}

#Preview("Small — Empty schedule", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.empty)
}

#Preview("Medium — Empty schedule", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.empty)
}

#Preview("Small — Not configured", as: .systemSmall) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.notConfigured)
}

#Preview("Medium — Not configured", as: .systemMedium) {
    NextCollectionWidget()
} timeline: {
    WidgetPreviewData.entry(payload: WidgetPreviewData.notConfigured)
}
#endif
