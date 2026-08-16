import SwiftUI

struct UpcomingCollectionCard: View {
    let occurrence: CollectionOccurrence

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline) {
                Text(occurrence.localDate.fullDescription)
                    .font(.headline)
                Spacer()
                Text("Scheduled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(occurrence.containers) { container in
                ContainerRow(container: container, compact: true)
            }
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}

