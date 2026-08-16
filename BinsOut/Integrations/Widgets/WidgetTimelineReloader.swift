import WidgetKit

protocol WidgetTimelineReloading: Sendable {
    func reloadCollectionWidget() async
}

struct WidgetTimelineReloader: WidgetTimelineReloading {
    func reloadCollectionWidget() async {
        WidgetCenter.shared.reloadTimelines(ofKind: BinsOutCollectionWidget.kind)
    }
}

struct NoopWidgetTimelineReloader: WidgetTimelineReloading {
    func reloadCollectionWidget() async {}
}
