import SwiftUI

struct ContainerRow: View {
    let container: ContainerKind
    var compact = false

    var body: some View {
        HStack {
            ContainerIcon(container: container, size: compact ? .compact : .regular)
            Text(container.sourceLabel)
                .bold()
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(container.sourceLabel)
    }
}

