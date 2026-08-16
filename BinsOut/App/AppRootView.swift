import EventKit
import SwiftUI

struct AppRootView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Group {
            switch appModel.loadState {
            case .notStarted, .loading:
                LaunchLoadingView()
            case .ready:
                if appModel.property == nil {
                    OnboardingView()
                } else {
                    MainTabView()
                }
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn’t open Bins Out", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again", systemImage: "arrow.clockwise") {
                        Task { await appModel.retryLoad() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .task {
            await appModel.load()
        }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged) {
                await appModel.calendarStoreChanged()
            }
        }
    }
}

private struct LaunchLoadingView: View {
    var body: some View {
        VStack {
            Image(systemName: "arrow.3.trianglepath")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            ProgressView("Opening Bins Out")
        }
    }
}
