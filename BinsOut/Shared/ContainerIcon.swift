import SwiftUI

struct ContainerIcon: View {
    let container: ContainerKind
    var size: Size = .regular

    @ScaledMetric(relativeTo: .body) private var compactBadgeDiameter: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var regularBadgeDiameter: CGFloat = 44

    enum Size {
        case compact
        case regular

        var imageStyle: Font {
            switch self {
            case .compact:
                .body
            case .regular:
                .title3
            }
        }
    }

    private var badgeDiameter: CGFloat {
        switch size {
        case .compact:
            compactBadgeDiameter
        case .regular:
            regularBadgeDiameter
        }
    }

    var body: some View {
        Image(systemName: container.displayMetadata.symbolName)
            .font(size.imageStyle)
            .foregroundStyle(container.displayMetadata.colorRole.tint)
            .frame(width: badgeDiameter, height: badgeDiameter)
            .background(container.displayMetadata.colorRole.tint.opacity(0.12), in: .circle)
            .accessibilityHidden(true)
    }
}

extension ContainerColorRole {
    var tint: Color {
        switch self {
        case .black:
            .gray
        case .green:
            .green
        case .blue:
            .blue
        case .brown:
            .brown
        case .garden:
            .mint
        case .communal:
            .purple
        case .unknown:
            .orange
        }
    }
}
