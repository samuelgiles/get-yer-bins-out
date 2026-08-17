import SwiftUI

/// Bristol's glass rule, shown rather than only spoken, so the exceptions carry equal
/// weight instead of trailing off a sentence. The official page stays one explicit tap away.
struct GlassSortingSnippetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Glass bottles and jars", systemImage: "shippingbox.fill")
                .font(.headline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                GlassSortingRow(
                    symbolName: "shippingbox.fill",
                    tint: .gray,
                    title: "Black recycling box",
                    detail: "Rinsed glass bottles and jars."
                )
                GlassSortingRow(
                    symbolName: "arrow.3.trianglepath",
                    tint: .green,
                    title: "Green recycling box",
                    detail: "Their lids."
                )
            }

            Text("Not broken glass, window glass, drinking glass, or Pyrex.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(intent: OpenGlassBottleGuidanceIntent()) {
                Label("Bristol’s official guidance", systemImage: "arrow.up.right.square")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .accessibilityElement(children: .contain)
    }
}

private struct GlassSortingRow: View {
    let symbolName: String
    let tint: Color
    let title: String
    let detail: String

    @ScaledMetric(relativeTo: .body) private var badgeDiameter: CGFloat = 32

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .foregroundStyle(tint)
                .frame(width: badgeDiameter, height: badgeDiameter)
                .background(tint.opacity(0.12), in: .circle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

#if DEBUG
#Preview("Snippet — Glass sorting") {
    GlassSortingSnippetView()
}
#endif
