import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct CollectionLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CollectionActivityAttributes.self) { context in
            CollectionActivityLockScreenView(context: context)
                .activityBackgroundTint(.green.opacity(0.12))
                .activitySystemActionForegroundColor(.green)
                .widgetURL(ActivityLinks.collection(context.attributes.occurrenceID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.3.trianglepath")
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.collectionDateShort)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(activityTitle(context: context))
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        ActivityContainerSummary(containers: context.attributes.containers)
                        Spacer()
                        BinsOutIntentButton(
                            occurrenceID: context.attributes.occurrenceID,
                            isPutOut: context.state.isPutOut
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPutOut ? "checkmark" : "arrow.3.trianglepath")
                    .foregroundStyle(context.state.isPutOut ? .green : .primary)
            } compactTrailing: {
                Text(context.state.isPutOut ? "Done" : "Tonight")
                    .font(.caption2)
            } minimal: {
                Image(systemName: context.state.isPutOut ? "checkmark" : "trash")
                    .foregroundStyle(context.state.isPutOut ? .green : .primary)
            }
            .keylineTint(.green)
            .widgetURL(ActivityLinks.collection(context.attributes.occurrenceID))
        }
    }
}

private struct CollectionActivityLockScreenView: View {
    let context: ActivityViewContext<CollectionActivityAttributes>

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Label(
                    activityTitle(context: context),
                    systemImage: context.state.isPutOut
                        ? "checkmark.circle.fill"
                        : isPreview(context: context) ? "play.rectangle.fill" : "moon.stars.fill"
                )
                .font(.headline)
                .foregroundStyle(context.state.isPutOut ? .green : .primary)

                Text(context.attributes.collectionDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ActivityContainerSummary(containers: context.attributes.containers)
            }

            Spacer(minLength: 12)

            BinsOutIntentButton(
                occurrenceID: context.attributes.occurrenceID,
                isPutOut: context.state.isPutOut
            )
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

private struct ActivityContainerSummary: View {
    let containers: [CollectionActivityAttributes.Container]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(containers.prefix(3)) { container in
                Label(container.name, systemImage: container.symbolName)
                    .font(.caption)
                    .lineLimit(1)
            }
            if containers.count > 3 {
                Text("+ \(containers.count - 3) more")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BinsOutIntentButton: View {
    let occurrenceID: String
    let isPutOut: Bool

    var body: some View {
        if isPutOut {
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption.bold())
                .foregroundStyle(.green)
        } else {
            Button(intent: MarkCollectionDoneIntent(occurrenceID: occurrenceID)) {
                Label(isPreview ? "Close" : "Bins out", systemImage: isPreview ? "xmark" : "checkmark")
                    .font(.caption.bold())
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .accessibilityLabel(isPreview ? "End Live Activity preview" : "Mark bins as put out")
        }
    }

    private var isPreview: Bool {
        SystemIdentifiers.isLiveActivityPreview(occurrenceID: occurrenceID)
    }
}

private func isPreview(context: ActivityViewContext<CollectionActivityAttributes>) -> Bool {
    SystemIdentifiers.isLiveActivityPreview(scheduleID: context.attributes.scheduleID)
}

private func activityTitle(context: ActivityViewContext<CollectionActivityAttributes>) -> String {
    CollectionActivityTitle.title(for: context.attributes.containers)
}

private enum ActivityLinks {
    static func collection(_ occurrenceID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "binsout"
        components.host = "collection"
        components.queryItems = [URLQueryItem(name: "occurrence", value: occurrenceID)]
        return components.url
    }
}

#if DEBUG
private let previewAttributes = CollectionActivityAttributes(
    occurrenceID: "preview-occurrence",
    scheduleID: "preview-occurrence|segment-0",
    collectionDate: "Friday, 21 August 2026",
    collectionDateShort: "21 Aug 2026",
    containers: [
        CollectionActivityAttributes.Container(
            id: "food",
            name: "Food waste bin",
            symbolName: "fork.knife"
        ),
        CollectionActivityAttributes.Container(
            id: "green",
            name: "Green recycling box",
            symbolName: "arrow.3.trianglepath"
        ),
    ]
)

#Preview("Lock Screen", as: .content, using: previewAttributes) {
    CollectionLiveActivityWidget()
} contentStates: {
    CollectionActivityAttributes.ContentState(isPutOut: false)
    CollectionActivityAttributes.ContentState(isPutOut: true)
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: previewAttributes) {
    CollectionLiveActivityWidget()
} contentStates: {
    CollectionActivityAttributes.ContentState(isPutOut: false)
}
#endif
