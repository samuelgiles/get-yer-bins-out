import SwiftUI

#if DEBUG
// App entry points

#Preview("App — Loading") {
    PreviewData.appView(AppRootView(), state: .launchLoading)
}

#Preview("App — Onboarding") {
    PreviewData.appView(AppRootView(), state: .onboarding)
}

#Preview("App — Launch error") {
    PreviewData.appView(AppRootView(), state: .launchFailure)
}

#Preview("Main tabs — Configured") {
    PreviewData.appView(MainTabView())
}

// Next screen state matrix

#Preview("Next — Loading schedule") {
    PreviewData.appView(NextCollectionView(), state: .checkingForSchedule)
}

#Preview("Next — Fresh schedule") {
    PreviewData.appView(NextCollectionView(), state: .fresh)
}

#Preview("Next — Recycling only") {
    PreviewData.appView(NextCollectionView(), state: .recyclingOnly)
}

#Preview("Next — Wheelie bin and recycling") {
    PreviewData.appView(NextCollectionView(), state: .wheelieBinMixed)
}

#Preview("Next — Garden waste") {
    PreviewData.appView(NextCollectionView(), state: .gardenWaste)
}

#Preview("Next — Empty schedule") {
    PreviewData.appView(NextCollectionView(), state: .empty)
}

#Preview("Next — Offline saved schedule") {
    PreviewData.appView(NextCollectionView(), state: .offline)
}

#Preview("Next — Refresh failed, retained data") {
    PreviewData.appView(NextCollectionView(), state: .refreshErrorWithRetainedData)
}

#Preview("Next — Accessibility") {
    PreviewData.appView(NextCollectionView())
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Next — Dark, increased contrast") {
    PreviewData.appView(NextCollectionView(), state: .wheelieBinMixed)
        .preferredColorScheme(.dark)
        .environment(\._colorSchemeContrast, .increased)
}

// Next screen components

#Preview("Next hero — Ready to put out") {
    NextCollectionHero(
        occurrence: PreviewData.recyclingOnlySnapshot.occurrences[0],
        isPutOut: false,
        togglePutOut: {}
    )
    .padding()
}

#Preview("Next hero — Already put out") {
    NextCollectionHero(
        occurrence: PreviewData.wheelieBinMixedSnapshot.occurrences[0],
        isPutOut: true,
        togglePutOut: {}
    )
    .padding()
}

#Preview("Upcoming collection card") {
    UpcomingCollectionCard(occurrence: PreviewData.freshSnapshot.occurrences[1])
        .padding()
}

#Preview("Coming up — Collapsed") {
    @Previewable @State var isExpanded = false
    ComingUpSection(
        compactOccurrences: Array(PreviewData.freshSnapshot.occurrences.dropFirst()),
        extendedOccurrences: PreviewData.freshSnapshot.occurrences,
        isExpanded: $isExpanded
    )
    .padding()
}

#Preview("Coming up — Expanded") {
    @Previewable @State var isExpanded = true
    ComingUpSection(
        compactOccurrences: Array(PreviewData.freshSnapshot.occurrences.dropFirst()),
        extendedOccurrences: PreviewData.freshSnapshot.occurrences,
        isExpanded: $isExpanded
    )
    .padding()
}

#Preview("Refresh issue") {
    RefreshIssueBanner(message: "Preview refresh could not reach the collection service.")
        .padding()
}

#Preview("Schedule freshness") {
    ScheduleFreshnessView(snapshot: PreviewData.freshSnapshot)
        .padding()
}

#Preview("Container rows") {
    VStack(alignment: .leading, spacing: 16) {
        ContainerRow(container: PreviewData.recyclingContainers[0])
        ContainerRow(container: PreviewData.wheelieBinMixedContainers[0], compact: true)
        ContainerRow(container: PreviewData.gardenWasteContainers[0])
    }
    .padding()
}

#Preview("Container icons — High contrast") {
    HStack(spacing: 16) {
        ContainerIcon(container: PreviewData.recyclingContainers[0])
        ContainerIcon(container: PreviewData.wheelieBinMixedContainers[0])
        ContainerIcon(container: PreviewData.gardenWasteContainers[0])
    }
    .padding()
    .environment(\._colorSchemeContrast, .increased)
}

// Onboarding state matrix

#Preview("Onboarding — Council") {
    PreviewData.appView(OnboardingView(), state: .onboarding)
}

#Preview("Council selection — Supported council") {
    @Previewable @State var council = CouncilID.bristolCityCouncil

    NavigationStack {
        CouncilSelectionView(council: $council, continueAction: {})
    }
}

#Preview("Onboarding — Property validation") {
    @Previewable @State var uprn = "not-a-number"
    @Previewable @State var displayName = ""

    NavigationStack {
        PropertyDetailsView(
            council: .bristolCityCouncil,
            uprn: $uprn,
            displayName: $displayName,
            providerDisplayName: "Preview schedule",
            isFixtureProvider: true,
            isWorking: false,
            validate: {}
        )
    }
}

#Preview("Onboarding — Property validation (reference too long)") {
    @Previewable @State var uprn = PreviewData.syntheticOverlongUPRN
    @Previewable @State var displayName = "Preview residence"

    NavigationStack {
        PropertyDetailsView(
            council: .bristolCityCouncil,
            uprn: $uprn,
            displayName: $displayName,
            providerDisplayName: "Preview schedule",
            isFixtureProvider: true,
            isWorking: false,
            validate: {}
        )
    }
}

#Preview("Onboarding — Schedule preview") {
    NavigationStack {
        SchedulePreviewView(
            validatedProperty: PreviewData.validatedProperty,
            isSaving: false,
            save: {}
        )
    }
}

// Other app screens

#Preview("Sort — Unconfigured") {
    PreviewData.appView(SortGuideView(), state: .unconfiguredSettings)
}

#Preview("Sort — Configured") {
    PreviewData.appView(SortGuideView(), state: .configuredSettings)
}

#Preview("Settings — Unconfigured") {
    PreviewData.appView(SettingsView(), state: .unconfiguredSettings)
}

#Preview("Settings — Configured") {
    PreviewData.appView(SettingsView(), state: .configuredSettings)
}
#endif
