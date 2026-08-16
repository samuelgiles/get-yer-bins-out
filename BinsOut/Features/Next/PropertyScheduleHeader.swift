import SwiftUI

struct PropertyScheduleHeader: View {
    let propertyName: String
    let isRefreshing: Bool
    let refresh: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    propertyLabel
                    refreshButton
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    propertyLabel
                    Spacer(minLength: 12)
                    refreshButton
                }
            }
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
        Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
            .buttonStyle(.bordered)
            .disabled(isRefreshing)
            .accessibilityHint("Checks Bristol's collection schedule again")
    }
}

#if DEBUG
#Preview("Schedule header · Accessibility") {
    PropertyScheduleHeader(
        propertyName: "Riverside flat in Bristol",
        isRefreshing: false,
        refresh: {}
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
