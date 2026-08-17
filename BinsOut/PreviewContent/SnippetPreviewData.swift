import Foundation

#if DEBUG
/// Deterministic contexts for the Siri snippet previews, reusing `PreviewData`'s
/// synthetic property so nothing here touches the App Group or a council.
enum SnippetPreviewData {
    static let scheduled = context(snapshot: PreviewData.freshSnapshot)

    static let putOut = context(snapshot: PreviewData.freshSnapshot, isNextPutOut: true)

    static let stale = context(snapshot: PreviewData.offlineSnapshot)

    static let noUpcoming = context(snapshot: PreviewData.emptySnapshot)

    static let notConfigured = CollectionAnswerContext(
        state: .notConfigured,
        today: today
    )

    static let unavailable = CollectionAnswerContext(
        state: .unavailable,
        today: today
    )

    private static let today = LocalDate(date: PreviewData.now)

    private static func context(
        snapshot: ScheduleSnapshot,
        isNextPutOut: Bool = false
    ) -> CollectionAnswerContext {
        var completionState = CompletionState()
        if isNextPutOut, let next = snapshot.upcoming(relativeTo: today).first {
            completionState.markPutOut(next.id, at: PreviewData.now)
        }

        return CollectionAnswerService.context(
            propertyDisplayName: PreviewData.property.displayName,
            snapshot: snapshot,
            completionState: completionState,
            today: today
        )
    }
}
#endif
