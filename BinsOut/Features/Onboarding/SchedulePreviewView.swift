import SwiftUI

struct SchedulePreviewView: View {
    let validatedProperty: ValidatedProperty
    let isSaving: Bool
    let save: () -> Void

    private var occurrences: [CollectionOccurrence] {
        validatedProperty.snapshot.occurrences
    }

    var body: some View {
        List {
            Section {
                Label("Schedule found", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
                LabeledContent("Property", value: validatedProperty.property.displayName)
                LabeledContent("Council", value: validatedProperty.property.council.displayName)
                LabeledContent("Source", value: validatedProperty.snapshot.providerDisplayName)
            } footer: {
                Text("These are scheduled collection dates. The feed does not confirm that a collection was completed.")
            }

            Section("Preview") {
                ForEach(occurrences.prefix(4)) { occurrence in
                    VStack(alignment: .leading) {
                        Text(occurrence.localDate.fullDescription)
                            .font(.headline)
                        ForEach(occurrence.containers) { container in
                            ContainerRow(container: container, compact: true)
                        }
                    }
                    .padding(.vertical)
                }
            }

            Section {
                Button {
                    save()
                } label: {
                    HStack {
                        Text("Save property")
                        Spacer()
                        if isSaving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .disabled(isSaving)
            } footer: {
                Text("Bins Out will keep this last good schedule on your device for offline use.")
            }
        }
        .navigationTitle("Check your dates")
        .navigationBarBackButtonHidden()
    }
}

