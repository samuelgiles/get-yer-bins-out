import SwiftUI

/// The card Siri and Spotlight show for a collection question: the same information the
/// app's own Next screen leads with, plus the Live Activity's "Bins out" action.
struct NextCollectionSnippetView: View {
    let context: CollectionAnswerContext

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch context.state {
            case .notConfigured:
                SnippetUnavailableView(
                    title: "Set up Bins Out",
                    detail: "Add a property to see its scheduled collections.",
                    symbolName: "house"
                )

            case .unavailable:
                SnippetUnavailableView(
                    title: "Schedule unavailable",
                    detail: "The saved schedule could not be read. Open Bins Out to refresh it.",
                    symbolName: "exclamationmark.triangle"
                )

            case let .noUpcoming(propertyDisplayName):
                SnippetUnavailableView(
                    title: "No saved dates",
                    detail: "No upcoming scheduled collections are saved for \(propertyDisplayName).",
                    symbolName: "calendar.badge.exclamationmark",
                    propertyDisplayName: propertyDisplayName
                )
                RefreshButton()

            case let .scheduled(propertyDisplayName, next, following):
                ScheduledCollectionSnippetContent(
                    propertyDisplayName: propertyDisplayName,
                    occurrence: next,
                    following: following.first,
                    context: context
                )
            }
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

private struct ScheduledCollectionSnippetContent: View {
    let propertyDisplayName: String
    let occurrence: CollectionOccurrence
    let following: CollectionOccurrence?
    let context: CollectionAnswerContext

    private var countdown: String {
        CollectionAnswerPhrasing.countdownDescription(
            for: occurrence.localDate,
            relativeTo: context.today
        )
    }

    var body: some View {
        Label(propertyDisplayName, systemImage: "house.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .lineLimit(1)

        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: context.isNextPutOut ? "checkmark.circle.fill" : occurrence.summary.symbolName)
                .foregroundStyle(context.isNextPutOut ? .green : .primary)
                .accessibilityHidden(true)
            Text(occurrence.summary.title)
                .font(.headline.weight(.semibold))
            Spacer(minLength: 8)
            Text(countdown)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }

        Text(occurrence.localDate.fullDescription)
            .font(.subheadline)
            .foregroundStyle(.secondary)

        VStack(alignment: .leading, spacing: 4) {
            Text(context.isNextPutOut ? "Put out" : "To put out")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            ForEach(occurrence.containers) { container in
                ContainerRow(container: container, compact: true)
            }
        }

        if let following {
            Text("Then \(following.summary.title.lowercased()) on \(following.localDate.shortDescription).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }

        Text(CollectionAnswerPhrasing.scheduledDatesCaveat)
            .font(.caption2)
            .foregroundStyle(.secondary)

        SnippetFreshnessFooter(context: context)

        HStack(spacing: 12) {
            if context.isNextPutOut {
                Label("Bins out", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Already marked as put out")
            } else {
                Button(intent: PutOutFromSnippetIntent(occurrenceID: occurrence.id)) {
                    Label("Bins out", systemImage: "checkmark")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .accessibilityLabel("Mark bins as put out")
            }

            RefreshButton()
        }
    }
}

private struct RefreshButton: View {
    var body: some View {
        Button(intent: RefreshScheduleIntent()) {
            Label("Refresh", systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .accessibilityLabel("Refresh the saved schedule")
    }
}

private struct SnippetFreshnessFooter: View {
    let context: CollectionAnswerContext

    var body: some View {
        HStack(spacing: 5) {
            if context.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .accessibilityHidden(true)
            }
            Text(text)
        }
        .font(.caption2)
        .foregroundStyle(context.isStale ? Color.orange : Color.secondary)
        .accessibilityLabel(context.isStale ? "\(text). The saved schedule may be out of date." : text)
    }

    private var text: String {
        guard let fetchedAt = context.fetchedAt else {
            return "No saved update yet"
        }
        let updated = "Updated \(fetchedAt.formatted(date: .abbreviated, time: .shortened))"
        return context.isStale ? "\(updated) · needs updating" : updated
    }
}

private struct SnippetUnavailableView: View {
    let title: String
    let detail: String
    let symbolName: String
    var propertyDisplayName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let propertyDisplayName {
                Label(propertyDisplayName, systemImage: "house.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Label(title, systemImage: symbolName)
                .font(.headline.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview("Snippet — Next collection") {
    NextCollectionSnippetView(context: SnippetPreviewData.scheduled)
}

#Preview("Snippet — Already put out") {
    NextCollectionSnippetView(context: SnippetPreviewData.putOut)
}

#Preview("Snippet — Stale schedule") {
    NextCollectionSnippetView(context: SnippetPreviewData.stale)
}

#Preview("Snippet — No saved dates") {
    NextCollectionSnippetView(context: SnippetPreviewData.noUpcoming)
}

#Preview("Snippet — Not configured") {
    NextCollectionSnippetView(context: SnippetPreviewData.notConfigured)
}

#Preview("Snippet — Schedule unavailable") {
    NextCollectionSnippetView(context: SnippetPreviewData.unavailable)
}
#endif
