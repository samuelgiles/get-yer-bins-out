import SwiftUI

struct PropertyDetailsView: View {
    let council: CouncilID
    @Binding var uprn: String
    @Binding var displayName: String
    let providerDisplayName: String
    let isFixtureProvider: Bool
    let isWorking: Bool
    let validate: () -> Void

    private var inlineUPRNError: String? {
        guard !uprn.isEmpty else { return nil }
        do {
            _ = try UPRNValidator.validated(uprn)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    var body: some View {
        Form {
            Section("Council") {
                LabeledContent("Selected", value: council.displayName)
            }

            Section {
                TextField("UPRN", text: $uprn)
                    .keyboardType(.numberPad)
                    .textContentType(.none)
                    .accessibilityHint("Enter up to 12 numbers. Leading zeroes are kept.")

                if let inlineUPRNError {
                    Label(inlineUPRNError, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Link("Find your UPRN", destination: BristolOfficialLinks.uprnFinder)
            } header: {
                Text("Property reference")
            } footer: {
                Text("Your Unique Property Reference Number is numbers only. Bins Out preserves it exactly as entered and sends only this value to the council service.")
            }

            Section {
                TextField("Home", text: $displayName)
                    .textContentType(.nickname)
            } header: {
                Text("Name this property")
            } footer: {
                Text("This is your private label. Bristol does not look it up or verify it; Bins Out syncs it with your selected property through iCloud Keychain.")
            }

            Section {
                Button {
                    validate()
                } label: {
                    HStack {
                        Text("Check collection dates")
                        Spacer()
                        if isWorking {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                }
                .disabled(isWorking)
            } footer: {
                if isFixtureProvider {
                    Text("Using a deterministic sample schedule for keyless development. No council request will be made.")
                } else {
                    Text("Dates will be checked directly with \(providerDisplayName).")
                }
            }
        }
        .navigationTitle("Your property")
        .navigationBarBackButtonHidden()
    }
}
