import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct CaelynWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

// MARK: - Timeline provider

struct CaelynWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaelynWidgetEntry {
        CaelynWidgetEntry(date: .now, snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (CaelynWidgetEntry) -> Void) {
        let snapshot = WidgetDataStore.read() ?? .placeholder()
        completion(CaelynWidgetEntry(date: .now, snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaelynWidgetEntry>) -> Void) {
        let snapshot = WidgetDataStore.read() ?? .placeholder()
        let entry = CaelynWidgetEntry(date: .now, snapshot: snapshot)
        // Refresh every 6 hours as a fallback. The main app also triggers
        // WidgetCenter.reloadAllTimelines() on every foreground activation
        // and background transition, so the widget is almost always current.
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 6, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Entry view switcher

struct CaelynWidgetEntryView: View {
    let entry: CaelynWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        case .systemLarge:
            LargeWidgetView(snapshot: entry.snapshot)
        case .accessoryCircular:
            AccessoryCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryRectangularView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}
