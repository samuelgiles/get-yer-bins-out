import SwiftUI

@main
struct BinsOutApp: App {
    @State private var appModel = AppEnvironment.makeAppModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
#if !targetEnvironment(macCatalyst)
        BinsOutAppShortcuts.updateAppShortcutParameters()
#endif
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appModel)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await appModel.syncPropertyFromCloud()
                await appModel.refreshPermissionStatuses()
                await appModel.reconcileSystemFeatures()
            }
        }
    }
}
