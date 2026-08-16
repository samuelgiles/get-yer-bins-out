import SwiftUI

struct CouncilSelectionView: View {
    @Binding var council: CouncilID
    let continueAction: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Image(systemName: "house.and.flag.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                    .padding(.bottom)
                    .accessibilityHidden(true)

                Text("Never miss bin night")
                    .font(.largeTitle)
                    .bold()
                Text("See exactly which containers are scheduled for your home, even when you’re offline.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)

                Text("Choose your council")
                    .font(.headline)

                ForEach(CouncilID.allCases) { option in
                    Button {
                        council = option
                    } label: {
                        HStack {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(.tint)
                            VStack(alignment: .leading) {
                                Text(option.displayName)
                                    .bold()
                                Text(option.isSupported ? "Available" : "Coming later")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: council == option ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(council == option ? Color.accentColor : Color.gray)
                        }
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 20))
                    }
                    .buttonStyle(.plain)
                    .disabled(!option.isSupported)
                    .accessibilityValue(council == option ? "Selected" : "Not selected")
                }
            }
            .padding()
        }
        .navigationTitle("Welcome")
        .safeAreaInset(edge: .bottom) {
            Button("Continue", systemImage: "arrow.right") {
                continueAction()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding()
            .background(.ultraThinMaterial)
        }
    }
}
