import SwiftUI

struct ScheduleFreshnessView: View {
    let snapshot: ScheduleSnapshot

    var body: some View {
        VStack(alignment: .leading) {
            Label(
                "Last updated \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened))",
                systemImage: "clock"
            )
            Text("Source: \(snapshot.providerDisplayName)")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

