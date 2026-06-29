import WidgetKit
import SwiftUI

// MARK: - Timeline entry

struct CaelynWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    /// false when there is no real cycle data yet → views show an empty state
    /// instead of fabricated sample numbers (plat-3).
    var hasData: Bool = true
}

// MARK: - Timeline provider

struct CaelynWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaelynWidgetEntry {
        // Gallery / redacted placeholder — sample content is appropriate here.
        CaelynWidgetEntry(date: .now, snapshot: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (CaelynWidgetEntry) -> Void) {
        completion(currentEntry(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CaelynWidgetEntry>) -> Void) {
        let cal = Calendar.current
        let now = Date()

        guard let base = WidgetDataStore.read(), base.anchorPeriodStart != nil else {
            // No data / no prediction yet → one empty entry, retry in 6h.
            let entry = CaelynWidgetEntry(date: now, snapshot: .placeholder(), hasData: false)
            let retry = cal.date(byAdding: .hour, value: 6, to: now) ?? now
            completion(Timeline(entries: [entry], policy: .after(retry)))
            return
        }

        // One entry for now + one at each local midnight for the next 7 days,
        // each recomputed from the anchors so the cycle day advances across
        // midnight without the app ever running (plat-3).
        var entries: [CaelynWidgetEntry] = [
            CaelynWidgetEntry(date: now, snapshot: base.recomputed(for: now))
        ]
        let startOfToday = cal.startOfDay(for: now)
        for offset in 1...7 {
            guard let midnight = cal.date(byAdding: .day, value: offset, to: startOfToday) else { continue }
            entries.append(CaelynWidgetEntry(date: midnight, snapshot: base.recomputed(for: midnight)))
        }
        let refresh = cal.date(byAdding: .day, value: 7, to: startOfToday) ?? now
        completion(Timeline(entries: entries, policy: .after(refresh)))
    }

    private func currentEntry(for now: Date) -> CaelynWidgetEntry {
        guard let base = WidgetDataStore.read(), base.anchorPeriodStart != nil else {
            return CaelynWidgetEntry(date: now, snapshot: .placeholder(), hasData: false)
        }
        return CaelynWidgetEntry(date: now, snapshot: base.recomputed(for: now), hasData: true)
    }
}

// MARK: - Entry view switcher

struct CaelynWidgetEntryView: View {
    let entry: CaelynWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if entry.hasData {
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
        } else {
            WidgetEmptyView(family: family)
        }
    }
}
