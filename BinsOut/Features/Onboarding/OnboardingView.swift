import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var appModel

    private let cancelAction: (() -> Void)?
    private let didSave: (() -> Void)?

    @State private var step: OnboardingStep = .council
    @State private var council: CouncilID = .bristolCityCouncil
    @State private var uprn = ""
    @State private var displayName = ""
    @State private var validatedProperty: ValidatedProperty?
    @State private var isWorking = false
    @State private var errorMessage = ""
    @State private var isShowingError = false

    init(
        initialProperty: Property? = nil,
        cancelAction: (() -> Void)? = nil,
        didSave: (() -> Void)? = nil
    ) {
        self.cancelAction = cancelAction
        self.didSave = didSave
        _council = State(initialValue: initialProperty?.council ?? .bristolCityCouncil)
        _uprn = State(initialValue: initialProperty?.uprn ?? "")
        _displayName = State(initialValue: initialProperty?.displayName ?? "")
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .council:
                    CouncilSelectionView(council: $council) {
                        step = .property
                    }
                case .property:
                    PropertyDetailsView(
                        council: council,
                        uprn: $uprn,
                        displayName: $displayName,
                        providerDisplayName: appModel.activeProviderDisplayName,
                        isFixtureProvider: appModel.isUsingFixtureProvider,
                        isWorking: isWorking,
                        validate: validate
                    )
                case .preview:
                    if let validatedProperty {
                        SchedulePreviewView(
                            validatedProperty: validatedProperty,
                            isSaving: isWorking,
                            save: save
                        )
                    }
                }
            }
            .toolbar {
                if step != .council {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Back", systemImage: "chevron.left") {
                            step = step == .preview ? .property : .council
                        }
                        .disabled(isWorking)
                    }
                }
                if cancelAction != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Cancel") {
                            cancelAction?()
                        }
                        .disabled(isWorking)
                    }
                }
            }
            .animation(.smooth, value: step)
            .alert("Couldn’t continue", isPresented: $isShowingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func validate() {
        isWorking = true
        Task {
            do {
                validatedProperty = try await appModel.validate(
                    council: council,
                    uprn: uprn,
                    displayName: displayName
                )
                step = .preview
            } catch {
                errorMessage = AppModel.message(for: error)
                isShowingError = true
            }
            isWorking = false
        }
    }

    private func save() {
        guard let validatedProperty else { return }
        isWorking = true
        Task {
            do {
                try await appModel.save(validatedProperty)
                isWorking = false
                didSave?()
            } catch {
                errorMessage = "The validated schedule could not be saved. Please try again."
                isShowingError = true
                isWorking = false
            }
        }
    }
}

private enum OnboardingStep {
    case council
    case property
    case preview
}
