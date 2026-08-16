import SwiftUI

struct CalendarSyncPreviewView: View {
    let plan: CalendarReconciliationPlan
    let calendarName: String
    let isApplying: Bool
    let apply: () -> Void
    let cancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Add", value: plan.additions, format: .number)
                    LabeledContent("Update", value: plan.updates, format: .number)
                    LabeledContent("Remove", value: plan.removals, format: .number)
                } header: {
                    Text("Proposed changes")
                } footer: {
                    Text("Only individual, all-day Bins Out events in the selected calendar are managed. No recurring series is created.")
                }

                if !plan.actions.isEmpty {
                    Section("Events") {
                        ForEach(Array(plan.actions.enumerated()), id: \.offset) { _, action in
                            CalendarChangeRow(action: action)
                        }
                    }
                }

                if !plan.newlySuppressedOccurrenceIDs.isEmpty {
                    Section {
                        Label(
                            "\(plan.newlySuppressedOccurrenceIDs.count) previously synced event(s) appear to have been deleted and will not be recreated.",
                            systemImage: "hand.raised.fill"
                        )
                    } footer: {
                        Text("This respects deletions made directly in Calendar.")
                    }
                }
            }
            .navigationTitle("Review calendar sync")
            .navigationSubtitle(calendarName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now", action: cancel)
                        .disabled(isApplying)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply", action: apply)
                        .disabled(isApplying)
                }
            }
            .overlay {
                if isApplying {
                    ProgressView("Updating Calendar")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 16))
                }
            }
        }
    }
}

private struct CalendarChangeRow: View {
    let action: CalendarReconciliationAction

    var body: some View {
        switch action {
        case .add(let descriptor):
            row("Add", symbol: "plus.circle.fill", tint: .green, descriptor: descriptor)
        case .update(let descriptor, _):
            row("Update", symbol: "arrow.triangle.2.circlepath", tint: .blue, descriptor: descriptor)
        case .remove(_, _, let localDate):
            Label {
                VStack(alignment: .leading) {
                    Text("Remove outdated collection")
                    Text(localDate.fullDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private func row(
        _ verb: String,
        symbol: String,
        tint: Color,
        descriptor: CalendarEventDescriptor
    ) -> some View {
        Label {
            VStack(alignment: .leading) {
                Text("\(verb): \(descriptor.title)")
                Text(descriptor.localDate.fullDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(tint)
        }
    }
}
