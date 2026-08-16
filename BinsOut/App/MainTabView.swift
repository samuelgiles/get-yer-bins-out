import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: AppTab = .next

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Next", systemImage: "calendar", value: .next) {
                NextCollectionView()
            }

            Tab("Sort", systemImage: "arrow.3.trianglepath", value: .sort) {
                SortGuideView()
            }

            Tab("Settings", systemImage: "gearshape", value: .settings) {
                SettingsView()
            }
        }
        .onOpenURL { url in
            if url.scheme == "binsout", url.host == "collection" {
                selectedTab = .next
            }
        }
    }
}

private enum AppTab: Hashable {
    case next
    case sort
    case settings
}
