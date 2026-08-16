import SwiftUI

struct PropertyScheduleHeader: View {
    let propertyName: String
    let isRefreshing: Bool
    let refresh: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            propertyLabel
            Spacer(minLength: 12)
            refreshButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private var propertyLabel: some View {
        Label {
            Text(propertyName)
                .font(.title2.weight(.semibold))
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                .multilineTextAlignment(.leading)
        } icon: {
            Image(systemName: "house.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Property: \(propertyName)")
    }

    private var refreshButton: some View {
        Button(action: refresh) {
            Image(systemName: "arrow.clockwise")
        }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .disabled(isRefreshing)
            .accessibilityLabel("Refresh")
            .accessibilityHint("Checks Bristol's collection schedule again")
    }
}

#if DEBUG
#Preview("Schedule header · Accessibility") {
    PropertyScheduleHeader(
        propertyName: "Preview residence",
        isRefreshing: false,
        refresh: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
