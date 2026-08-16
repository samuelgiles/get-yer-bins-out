import EventKit
@preconcurrency import EventKitUI
import SwiftUI

struct SelectedCalendar: Equatable, Sendable {
    let identifier: String
    let title: String
}

struct CalendarChooserView: UIViewControllerRepresentable {
    let initiallySelectedIdentifier: String?
    let onSelect: (SelectedCalendar) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let store = EKEventStore()
        let chooser = EKCalendarChooser(
            selectionStyle: .single,
            displayStyle: .writableCalendarsOnly,
            entityType: .event,
            eventStore: store
        )
        chooser.delegate = context.coordinator
        chooser.showsDoneButton = true
        chooser.showsCancelButton = true
        if let initiallySelectedIdentifier,
           let calendar = store.calendar(withIdentifier: initiallySelectedIdentifier) {
            chooser.selectedCalendars = [calendar]
        }
        context.coordinator.chooser = chooser
        context.coordinator.eventStore = store
        return UINavigationController(rootViewController: chooser)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) { }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency EKCalendarChooserDelegate {
        let onSelect: (SelectedCalendar) -> Void
        let onCancel: () -> Void
        var chooser: EKCalendarChooser?
        var eventStore: EKEventStore?

        init(onSelect: @escaping (SelectedCalendar) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func calendarChooserDidFinish(_ calendarChooser: EKCalendarChooser) {
            guard let calendar = calendarChooser.selectedCalendars.first else {
                onCancel()
                return
            }
            onSelect(SelectedCalendar(identifier: calendar.calendarIdentifier, title: calendar.title))
        }

        func calendarChooserDidCancel(_ calendarChooser: EKCalendarChooser) {
            onCancel()
        }
    }
}
