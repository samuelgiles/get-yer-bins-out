import SwiftUI

struct NextCollectionHero: View {
    let occurrence: CollectionOccurrence
    let isPutOut: Bool
    let togglePutOut: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Label("Next scheduled collection", systemImage: "calendar.badge.clock")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(occurrence.localDate.fullDescription)
                .font(.largeTitle)
                .bold()
                .minimumScaleFactor(0.8)

            Text("Put out \(occurrence.localDate.adding(days: -1).shortDescription) evening")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom)

            ForEach(occurrence.containers) { container in
                ContainerRow(container: container)
            }

            Group {
                if isPutOut {
                    Button("Undo bins out", systemImage: "arrow.uturn.backward", action: togglePutOut)
                        .buttonStyle(.bordered)
                        .accessibilityHint("Marks these containers as not yet put out")
                } else {
                    Button("Bins out", systemImage: "checkmark.circle.fill", action: togglePutOut)
                        .buttonStyle(.borderedProminent)
                        .accessibilityHint("Marks these containers as put out and ends their reminders")
                }
            }
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .overlay {
            RoundedRectangle(cornerRadius: 28)
                .stroke(.tint.opacity(0.18))
        }
        .accessibilityElement(children: .contain)
    }
}
