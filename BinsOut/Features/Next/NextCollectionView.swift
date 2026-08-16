import SwiftUI

struct NextCollectionView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isShowingExtendedSchedule = false

    private var upcoming: [CollectionOccurrence] {
        appModel.snapshot?.upcoming(relativeTo: appModel.currentLocalDate) ?? []
    }

    var body: some View {
        NavigationStack {
            Group {
                if let snapshot = appModel.snapshot {
                    if let next = upcoming.first {
                        scheduleContent(snapshot: snapshot, next: next)
                    } else {
                        emptyScheduleContent(snapshot: snapshot)
                    }
                } else if appModel.refreshState == .refreshing {
                    ProgressView("Checking collection dates")
                } else {
                    missingScheduleContent
                }
            }
            .navigationTitle(appModel.property?.displayName ?? "Next collection")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task { await appModel.refresh() }
                    }
                    .disabled(appModel.refreshState == .refreshing)
                }
            }
        }
        .task {
            if appModel.snapshot == nil {
                await appModel.refresh()
            }
        }
        .onChange(of: appModel.property?.id) {
            isShowingExtendedSchedule = false
        }
    }

    private func scheduleContent(snapshot: ScheduleSnapshot, next: CollectionOccurrence) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading) {
                if let refreshError = snapshot.lastRefreshError {
                    RefreshIssueBanner(message: refreshError)
                }

                NextCollectionHero(
                    occurrence: next,
                    isPutOut: appModel.isPutOut(next.id)
                ) {
                    Task {
                        if appModel.isPutOut(next.id) {
                            await appModel.undoPutOut(next.id)
                        } else {
                            await appModel.markPutOut(next.id)
                        }
                    }
                }

                let compactOccurrences = comingUpOccurrences(
                    in: snapshot,
                    excluding: next,
                    weeks: 6
                )
                let extendedOccurrences = comingUpOccurrences(
                    in: snapshot,
                    excluding: next,
                    weeks: 24
                )

                if !extendedOccurrences.isEmpty {
                    ComingUpSection(
                        compactOccurrences: compactOccurrences,
                        extendedOccurrences: extendedOccurrences,
                        isExpanded: $isShowingExtendedSchedule
                    )
                }

                ScheduleFreshnessView(snapshot: snapshot)
                    .padding(.top)
            }
            .padding()
        }
        .refreshable {
            await appModel.refresh()
        }
        .overlay {
            if appModel.refreshState == .refreshing {
                ProgressView()
                    .controlSize(.large)
                    .padding()
                    .background(.regularMaterial, in: .circle)
                    .accessibilityLabel("Refreshing collection dates")
            }
        }
    }

    private func comingUpOccurrences(
        in snapshot: ScheduleSnapshot,
        excluding next: CollectionOccurrence,
        weeks: Int
    ) -> [CollectionOccurrence] {
        snapshot
            .upcoming(relativeTo: appModel.currentLocalDate, withinWeeks: weeks)
            .filter { $0.id != next.id }
    }

    private func emptyScheduleContent(snapshot: ScheduleSnapshot) -> some View {
        ContentUnavailableView {
            Label("No upcoming collections", systemImage: "calendar.badge.exclamationmark")
        } description: {
            Text("The saved schedule has no future dates. It was last checked \(snapshot.fetchedAt.formatted(date: .abbreviated, time: .shortened)).")
        } actions: {
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task { await appModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var missingScheduleContent: some View {
        ContentUnavailableView {
            Label("Schedule unavailable", systemImage: "wifi.exclamationmark")
        } description: {
            Text(appModel.standaloneErrorMessage ?? "No saved collection schedule is available yet.")
        } actions: {
            Button("Try again", systemImage: "arrow.clockwise") {
                Task { await appModel.refresh() }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
