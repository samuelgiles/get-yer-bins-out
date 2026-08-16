import SwiftUI

struct RefreshIssueBanner: View {
    let message: String

    var body: some View {
        Label {
            VStack(alignment: .leading) {
                Text("Saved schedule")
                    .bold()
                Text(message)
                    .font(.subheadline)
            }
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .foregroundStyle(.orange)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 16))
    }
}

