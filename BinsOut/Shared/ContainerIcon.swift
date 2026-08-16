import SwiftUI

struct ContainerIcon: View {
    let container: ContainerKind
    var size: Size = .regular

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

        var padding: CGFloat {
            switch self {
            case .compact:
                8
            case .regular:
                12
            }
        }
    }

    var body: some View {
        Image(systemName: container.displayMetadata.symbolName)
            .font(size.imageStyle)
            .foregroundStyle(container.displayMetadata.colorRole.tint)
            .padding(size.padding)
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

