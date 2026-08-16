import SwiftUI

struct ContainerRow: View {
    let container: ContainerKind
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            ContainerIcon(container: container, size: compact ? .compact : .regular)
            Text(container.sourceLabel)
                .fontWeight(.semibold)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(container.sourceLabel)
    }
}
