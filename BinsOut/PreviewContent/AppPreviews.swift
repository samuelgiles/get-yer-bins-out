import SwiftUI

#if DEBUG
#Preview("Onboarding") {
    AppRootView()
        .environment(PreviewData.model(property: nil, snapshot: nil))
}

#Preview("Next collection") {
    NextCollectionView()
        .environment(PreviewData.model())
}

#Preview("Next · Offline") {
    let offline = PreviewData.snapshot.recordingRefreshFailure(
        at: PreviewData.fetchedAt,
        message: "You appear to be offline. Showing the last saved schedule."
    )
    NextCollectionView()
        .environment(PreviewData.model(snapshot: offline))
}

#Preview("Next · Accessibility") {
    NextCollectionView()
        .environment(PreviewData.model())
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Next · Empty") {
    let empty = ScheduleSnapshot(
        propertyID: PreviewData.property.id,
        occurrences: [],
        providerIdentifier: "fixture",
        providerDisplayName: "Sample schedule",
        fetchedAt: PreviewData.fetchedAt
    )
    NextCollectionView()
        .environment(PreviewData.model(snapshot: empty))
}

#Preview("Settings · Live Activity preview") {
    SettingsView()
        .environment(PreviewData.model())
}
#endif
