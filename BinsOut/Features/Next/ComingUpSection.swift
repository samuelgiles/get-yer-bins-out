import SwiftUI

struct ComingUpSection: View {
    let compactOccurrences: [CollectionOccurrence]
    let extendedOccurrences: [CollectionOccurrence]
    @Binding var isExpanded: Bool

    private var visibleOccurrences: [CollectionOccurrence] {
        isExpanded ? extendedOccurrences : compactOccurrences
    }

    private var canExpand: Bool {
        extendedOccurrences.count > compactOccurrences.count
    }

    var body: some View {
        VStack(alignment: .leading) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Coming up")
                    .font(.title2)
                    .bold()

                Text(isExpanded ? "Available dates in the next 24 weeks" : "Next 6 weeks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if visibleOccurrences.isEmpty {
                Text("No other scheduled collections in the next 6 weeks.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(visibleOccurrences) { occurrence in
                    UpcomingCollectionCard(occurrence: occurrence)
                }
            }

            if canExpand {
                Button(
                    isExpanded ? "Show less" : "View more",
                    systemImage: isExpanded ? "chevron.up" : "chevron.down"
                ) {
                    isExpanded.toggle()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .accessibilityHint(
                    isExpanded
                        ? "Shows scheduled collections in the next six weeks"
                        : "Shows available scheduled collections in the next twenty-four weeks"
                )
            }
        }
        .padding(.top)
    }
}
