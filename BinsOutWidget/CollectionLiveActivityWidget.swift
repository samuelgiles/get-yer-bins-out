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
            let display = activityDisplay(context: context)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: display.symbolName)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(context.state.isPutOut ? .green : .primary)
                        .accessibilityHidden(true)
                }
                DynamicIslandExpandedRegion(.trailing, priority: 1) {
                    Text(CollectionActivityDisplay.dynamicIslandDate(for: context.attributes.collectionDateShort))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .allowsTightening(true)
                        .accessibilityLabel("Scheduled collection \(context.attributes.collectionDate)")
                }
                DynamicIslandExpandedRegion(.center, priority: 1) {
                    Text(display.title)
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .allowsTightening(true)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(alignment: .top, spacing: 8) {
                        ActivityContainerSummary(containers: context.attributes.containers)
                        Spacer(minLength: 8)
                        BinsOutIntentButton(
                            occurrenceID: context.attributes.occurrenceID,
                            isPutOut: context.state.isPutOut
                        )
                    }
                }
            } compactLeading: {
                Image(systemName: context.state.isPutOut ? "checkmark" : display.symbolName)
                    .foregroundStyle(context.state.isPutOut ? .green : .primary)
                    .accessibilityLabel(context.state.isPutOut ? "Bins are out" : display.title)
            } compactTrailing: {
                Text(context.state.isPutOut ? "Done" : "Tonight")
                    .font(.caption2.weight(.medium))
                    .accessibilityLabel(
                        context.state.isPutOut
                            ? "Bins are out"
                            : "Scheduled collection \(context.attributes.collectionDate)"
                    )
            } minimal: {
                Image(systemName: context.state.isPutOut ? "checkmark" : display.symbolName)
                    .foregroundStyle(context.state.isPutOut ? .green : .primary)
                    .accessibilityLabel(context.state.isPutOut ? "Bins are out" : display.title)
            }
            .keylineTint(.green)
            .widgetURL(ActivityLinks.collection(context.attributes.occurrenceID))
        }
    }
}

private struct CollectionActivityLockScreenView: View {
    let context: ActivityViewContext<CollectionActivityAttributes>

    private var display: CollectionActivityDisplay {
        activityDisplay(context: context)
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Label(display.title, systemImage: context.state.isPutOut ? "checkmark.circle.fill" : display.symbolName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(context.state.isPutOut ? .green : .primary)
                    .accessibilityLabel(context.state.isPutOut ? "Bins are out" : display.title)

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

private func activityDisplay(context: ActivityViewContext<CollectionActivityAttributes>) -> CollectionActivityDisplay {
    CollectionActivityDisplay.make(for: context.attributes.containers)
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
// Lock Screen previews

#Preview("Live Activity — Recycling — Lock Screen", as: .content, using: LiveActivityPreviewData.recycling) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
    LiveActivityPreviewData.complete
}

#Preview("Live Activity — Wheelie bin and recycling — Lock Screen", as: .content, using: LiveActivityPreviewData.wheelieBinMixed) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Garden waste — Lock Screen", as: .content, using: LiveActivityPreviewData.gardenWaste) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

// Dynamic Island previews. ActivityKit supports expanded, compact, and minimal
// canvas presentations; each collection type gets all three.

#Preview("Live Activity — Recycling — Dynamic Island expanded", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.recycling) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Recycling — Dynamic Island compact", as: .dynamicIsland(.compact), using: LiveActivityPreviewData.recycling) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Recycling — Dynamic Island minimal", as: .dynamicIsland(.minimal), using: LiveActivityPreviewData.recycling) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Wheelie bin and recycling — Dynamic Island expanded", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.wheelieBinMixed) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Wheelie bin and recycling — Dynamic Island compact", as: .dynamicIsland(.compact), using: LiveActivityPreviewData.wheelieBinMixed) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Wheelie bin and recycling — Dynamic Island minimal", as: .dynamicIsland(.minimal), using: LiveActivityPreviewData.wheelieBinMixed) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Garden waste — Dynamic Island expanded", as: .dynamicIsland(.expanded), using: LiveActivityPreviewData.gardenWaste) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Garden waste — Dynamic Island compact", as: .dynamicIsland(.compact), using: LiveActivityPreviewData.gardenWaste) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}

#Preview("Live Activity — Garden waste — Dynamic Island minimal", as: .dynamicIsland(.minimal), using: LiveActivityPreviewData.gardenWaste) {
    CollectionLiveActivityWidget()
} contentStates: {
    LiveActivityPreviewData.upcoming
}
#endif
