import SwiftUI
import SwiftData
import WidgetKit

// ─────────────────────────────────────────────────────────────────────────────
// Main app only. Builds WidgetSnapshot from live SwiftData models and writes
// it to the App Group UserDefaults so CaelynWidget can read it.
// ─────────────────────────────────────────────────────────────────────────────

// MARK: - Snapshot builder

enum WidgetSnapshotBuilder {
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// - Parameter now: injectable only so a test can prove the widget shows the
    ///   same cycle day as the app for a given history. Production always passes
    ///   the real clock.
    static func build(profile: UserProfile?, entries: [CycleEntry], isPro: Bool,
                      now: Date = Date()) -> WidgetSnapshot {
        let today = Calendar.current.startOfDay(for: now)
        // The widget and the Watch show the same numbers as the app because they
        // are literally the same derivation, computed once here.
        let cycle = CycleModel.make(entries: entries, profile: profile, today: today)

        let cycleLength = cycle.cycleLength
        let periodLength = cycle.periodLength
        let lastStart = cycle.anchor
        let cycleDay = cycle.cycleDay
        let phase = cycle.phase
        let nextStart = cycle.nextPeriodStart

        let daysUntilPeriod = nextStart.map { PredictionEngine.daysUntil($0, from: today) } ?? -1

        let periodWindowText: String = {
            guard let w = cycle.predictedPeriodWindow else { return "" }
            return "\(dateFmt.string(from: w.lowerBound))–\(dateFmt.string(from: w.upperBound))"
        }()

        var lines: [String] = []
        if nextStart != nil, let fertile = cycle.fertileWindow {
            let daysToFertile = PredictionEngine.daysUntil(fertile.lowerBound, from: today)
            let fertileRange = "\(dateFmt.string(from: fertile.lowerBound))–\(dateFmt.string(from: fertile.upperBound))"
            if phase != .ovulation && daysToFertile <= 14 {
                if daysToFertile <= 0 {
                    lines.append("Fertile window: \(fertileRange)")
                } else if daysToFertile == 1 {
                    lines.append("Fertile window starts tomorrow")
                } else {
                    lines.append("Fertile window in \(daysToFertile) days")
                }
            }
            let daysToPMS = cycle.daysUntilPMS
            if phase != .pms && daysToPMS > 0 && daysToPMS <= 14 {
                lines.append("PMS may begin in \(daysToPMS) day\(daysToPMS == 1 ? "" : "s")")
            }
            if phase != .menstrual && daysUntilPeriod > 0 && daysUntilPeriod <= 21 {
                lines.append("Period in \(daysUntilPeriod) day\(daysUntilPeriod == 1 ? "" : "s")")
            }
        }

        return WidgetSnapshot(
            cycleDay: cycleDay,
            cycleLength: cycleLength,
            phaseRaw: phase.rawValue,
            phaseName: phase.displayName,
            phaseIcon: phase.icon,
            phaseAccentHex: phase.widgetAccentHex,
            phaseTintHex: phase.widgetTintHex,
            daysUntilPeriod: daysUntilPeriod,
            periodWindowText: periodWindowText,
            upcomingLine1: lines.count > 0 ? lines[0] : "",
            upcomingLine2: lines.count > 1 ? lines[1] : "",
            upcomingLine3: lines.count > 2 ? lines[2] : "",
            isPro: isPro,
            updatedAt: Date(),
            // Anchors so the widget/watch can recompute the day across midnight
            // without the app running (plat-2). nil anchor = no prediction.
            anchorPeriodStart: lastStart,
            periodLength: periodLength,
            fertilityStatusRaw: WidgetCycleMath.fertilityStatus(cycleDay: cycleDay, cycleLength: cycleLength),
            hidePreview: profile?.hidePreview ?? false
        )
    }
}

// MARK: - CyclePhase hex values for widget

extension CyclePhase {
    var widgetAccentHex: Int {
        switch self {
        case .menstrual:  return 0xEFA7B2
        case .follicular: return 0xC9A87A
        case .ovulation:  return 0x6E9B7B
        case .luteal:     return 0xC9A87A
        case .pms:        return 0x6F3D74
        case .unknown:    return 0x6F3D74
        }
    }

    var widgetTintHex: Int {
        switch self {
        case .menstrual:  return 0xFBE4E7
        case .follicular: return 0xF9EFE7
        case .ovulation:  return 0xDCEBDD
        case .luteal:     return 0xFAF0E8
        case .pms:        return 0xEEE7FF
        case .unknown:    return 0xEEE7FF
        }
    }
}

// MARK: - View modifier (applied in CaelynApp)

struct WidgetDataSyncModifier: ViewModifier {
    @Query(sort: \UserProfile.createdAt) private var profiles: [UserProfile]
    @Query(sort: \CycleEntry.date, order: .reverse) private var entries: [CycleEntry]
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { sync() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active || phase == .background { sync() }
            }
    }

    private func sync() {
        let snapshot = WidgetSnapshotBuilder.build(
            profile: profiles.first,
            entries: entries,
            isPro: PurchaseService.shared.isPro
        )
        WidgetDataStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
        if PurchaseService.shared.isPro {
            WatchBridgeService.shared.pushSnapshot(snapshot)
        }
    }
}

extension View {
    func syncWidgetData() -> some View {
        modifier(WidgetDataSyncModifier())
    }
}
