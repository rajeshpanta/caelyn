import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// Shared between the Caelyn main app, CaelynWidget extension, and CaelynWatch.
// Pure Foundation — no SwiftUI, no WidgetKit, no app-specific types — so it
// compiles in every target without pulling in CyclePhase / PredictionEngine /
// SwiftData. The recompute math here MIRRORS PredictionEngine so the widget and
// watch can advance the day across local midnight without reopening the app
// (plat-1/plat-2). A unit test asserts parity with PredictionEngine.
// Register the App Group in developer.apple.com before first use:
//   group.smallpanta-icould.com.caelynperiodtracker
// ─────────────────────────────────────────────────────────────────────────────

let caelynAppGroupID = "group.smallpanta-icould.com.caelynperiodtracker"
private let widgetSnapshotKey = "caelynWidgetSnapshot"

/// Lightweight, Codable snapshot of the user's current cycle state.
/// Uses only primitive types so it compiles cleanly in every target.
///
/// The day-sensitive display fields (`cycleDay`, `daysUntilPeriod`, `phase*`,
/// `fertilityStatusRaw`) are written by the app for "today", but the widget and
/// watch call `recomputed(for:)` to refresh them for the current day — so a
/// snapshot written yesterday still shows the right day after midnight.
struct WidgetSnapshot: Codable {
    var cycleDay: Int           // 1-indexed; 1 if no profile
    var cycleLength: Int        // total days in cycle (default 28)
    var phaseRaw: String        // CyclePhase.rawValue
    var phaseName: String       // display name e.g. "Follicular"
    var phaseIcon: String       // SF Symbol name e.g. "leaf.fill"
    var phaseAccentHex: Int     // 0xRRGGBB for accent color
    var phaseTintHex: Int       // 0xRRGGBB for background tint
    var daysUntilPeriod: Int    // 0 = today/ongoing; -1 = no prediction
    var periodWindowText: String // "Jun 20–25", empty if no prediction
    var upcomingLine1: String   // first coming-up event (empty if none)
    var upcomingLine2: String   // second
    var upcomingLine3: String   // third
    var isPro: Bool
    var updatedAt: Date

    // ── Recompute anchors (plat-2). Optional so older snapshots still decode. ──
    /// The lastPeriodStart used to build this snapshot. nil = no prediction
    /// (recompute is a no-op and the widget/watch show their empty state).
    var anchorPeriodStart: Date? = nil
    /// Average period length, for phase recompute.
    var periodLength: Int? = nil
    /// Structured fertility for the watch: "ovulation" | "fertile" | "none".
    /// Replaces fragile substring matching on `upcomingLine1`.
    var fertilityStatusRaw: String? = nil
    /// Mirror of profile.hidePreview, so lock-screen accessory widgets can mask
    /// cycle data when the user has hide-preview enabled (plat-5).
    var hidePreview: Bool? = nil
}

extension WidgetSnapshot {
    /// Sample data for SwiftUI previews and the widget gallery only — never the
    /// no-data state on device. `isPro: false` so the gallery shows the free tier.
    static func placeholder() -> WidgetSnapshot {
        WidgetSnapshot(
            cycleDay: 14,
            cycleLength: 28,
            phaseRaw: "follicular",
            phaseName: "Follicular",
            phaseIcon: "leaf.fill",
            phaseAccentHex: 0xC9A87A,
            phaseTintHex: 0xF9EFE7,
            daysUntilPeriod: 14,
            periodWindowText: "Jul 10–15",
            upcomingLine1: "Fertile window in 3 days",
            upcomingLine2: "Period in 14 days",
            upcomingLine3: "",
            isPro: false,
            updatedAt: .now,
            anchorPeriodStart: nil,
            periodLength: 5,
            fertilityStatusRaw: "none",
            hidePreview: false
        )
    }

    /// Returns a copy with the day-sensitive fields recomputed for `now`, using
    /// the stored anchors. Returns self unchanged when there's no anchor (no
    /// prediction) — the caller then shows its empty state. (plat-1)
    func recomputed(for now: Date, calendar: Calendar = .current) -> WidgetSnapshot {
        guard let anchor = anchorPeriodStart else { return self }
        let cal = calendar
        let day0 = cal.startOfDay(for: anchor)
        let today = cal.startOfDay(for: now)
        let safeLen = max(cycleLength, 1)
        let pLen = max(periodLength ?? 5, 1)

        let daysSince = max(0, cal.dateComponents([.day], from: day0, to: today).day ?? 0)
        let newCycleDay = (daysSince % safeLen) + 1

        // Next period start — mirrors PredictionEngine.nextPeriodStart.
        var nextStart = cal.date(byAdding: .day, value: safeLen, to: day0) ?? today
        var iter = 0
        while nextStart < today {
            nextStart = cal.date(byAdding: .day, value: safeLen, to: nextStart) ?? nextStart
            iter += 1
            if iter > 3650 { break }
        }
        let newDaysUntil = max(0, cal.dateComponents([.day], from: today, to: nextStart).day ?? 0)
        let raw = WidgetCycleMath.phaseRaw(cycleDay: newCycleDay, periodLength: pLen, cycleLength: safeLen)

        var s = self
        s.cycleDay = newCycleDay
        s.daysUntilPeriod = newDaysUntil
        s.phaseRaw = raw
        s.phaseName = WidgetCycleMath.displayName(raw)
        s.phaseIcon = WidgetCycleMath.icon(raw)
        s.phaseAccentHex = WidgetCycleMath.accentHex(raw)
        s.phaseTintHex = WidgetCycleMath.tintHex(raw)
        s.fertilityStatusRaw = WidgetCycleMath.fertilityStatus(cycleDay: newCycleDay, cycleLength: safeLen)

        // Regenerate the day-relative text too, so Medium/Large widgets and the
        // watch don't show stale countdowns that contradict the advanced day (review).
        let strings = WidgetCycleMath.upcomingStrings(
            nextStart: nextStart, today: today, periodLength: pLen,
            phaseRaw: raw, daysUntilPeriod: newDaysUntil, calendar: cal)
        s.periodWindowText = strings.window
        s.upcomingLine1 = strings.lines.count > 0 ? strings.lines[0] : ""
        s.upcomingLine2 = strings.lines.count > 1 ? strings.lines[1] : ""
        s.upcomingLine3 = strings.lines.count > 2 ? strings.lines[2] : ""
        return s
    }
}

/// Pure cycle math shared by the app's PredictionEngine semantics and the
/// widget/watch recompute. Keep these in lockstep with PredictionEngine —
/// `WidgetCycleMathTests` asserts parity. (plat-1)
enum WidgetCycleMath {
    /// Phase classification for a 1-indexed cycle day. Mirrors
    /// PredictionEngine.phase exactly, returning the CyclePhase.rawValue.
    static func phaseRaw(cycleDay day: Int, periodLength: Int, cycleLength: Int) -> String {
        guard cycleLength > 0 else { return "unknown" }
        let safePeriod = max(1, periodLength)
        let ovulation = cycleLength - 14
        guard ovulation > safePeriod else {
            return (day >= 1 && day <= safePeriod) ? "menstrual" : "unknown"
        }
        let pmsStart = max(1, cycleLength - 4)
        if day >= 1 && day <= safePeriod { return "menstrual" }
        if day >= pmsStart && day <= cycleLength { return "pms" }
        if abs(day - ovulation) <= 1 { return "ovulation" }
        if day < ovulation { return "follicular" }
        return "luteal"
    }

    /// Fertile status for a cycle day. Mirrors PredictionEngine's *date-based*
    /// fertile window: ovulation = nextPeriodStart − 14, whose cycle day is
    /// `cycleLength − 13` (not −14, which is the phase-classification convention).
    /// Window = ovulation−4 … ovulation+1; ovulation status within ±1 day.
    static func fertilityStatus(cycleDay day: Int, cycleLength: Int) -> String {
        let ovulation = cycleLength - 13
        guard ovulation > 0 else { return "none" }
        if abs(day - ovulation) <= 1 { return "ovulation" }
        if day >= ovulation - 4 && day <= ovulation + 1 { return "fertile" }
        return "none"
    }

    /// Regenerate the day-relative display strings (period window + up to three
    /// "coming up" lines) for the recomputed day, mirroring WidgetSnapshotBuilder.
    /// Without this, the widget/watch advance the cycle-day number across midnight
    /// but keep stale countdowns ("Period in 14 days") that contradict it (review).
    static func upcomingStrings(nextStart: Date, today: Date, periodLength: Int,
                                phaseRaw: String, daysUntilPeriod: Int,
                                calendar cal: Calendar) -> (window: String, lines: [String]) {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let startOfToday = cal.startOfDay(for: today)
        func daysUntil(_ d: Date) -> Int {
            max(0, cal.dateComponents([.day], from: startOfToday, to: cal.startOfDay(for: d)).day ?? 0)
        }
        let pLen = max(periodLength, 1)
        let windowEnd = cal.date(byAdding: .day, value: pLen - 1, to: nextStart) ?? nextStart
        let window = "\(fmt.string(from: nextStart))–\(fmt.string(from: windowEnd))"

        var lines: [String] = []
        let ovulation = cal.date(byAdding: .day, value: -14, to: nextStart) ?? nextStart
        let fertileStart = cal.date(byAdding: .day, value: -4, to: ovulation) ?? ovulation
        let fertileEnd = cal.date(byAdding: .day, value: 1, to: ovulation) ?? ovulation
        let daysToFertile = daysUntil(fertileStart)
        if phaseRaw != "ovulation" && daysToFertile <= 14 && fertileEnd >= startOfToday {
            if daysToFertile <= 0 {
                lines.append("Fertile window: \(fmt.string(from: fertileStart))–\(fmt.string(from: fertileEnd))")
            } else if daysToFertile == 1 {
                lines.append("Fertile window starts tomorrow")
            } else {
                lines.append("Fertile window in \(daysToFertile) days")
            }
        }
        let pmsStart = cal.date(byAdding: .day, value: -5, to: nextStart) ?? nextStart
        let daysToPMS = daysUntil(pmsStart)
        if phaseRaw != "pms" && daysToPMS > 0 && daysToPMS <= 14 {
            lines.append("PMS may begin in \(daysToPMS) day\(daysToPMS == 1 ? "" : "s")")
        }
        if phaseRaw != "menstrual" && daysUntilPeriod > 0 && daysUntilPeriod <= 21 {
            lines.append("Period in \(daysUntilPeriod) day\(daysUntilPeriod == 1 ? "" : "s")")
        }
        return (window, lines)
    }

    static func displayName(_ raw: String) -> String {
        switch raw {
        case "menstrual":  return "Menstrual"
        case "follicular": return "Follicular"
        case "ovulation":  return "Ovulation window"
        case "luteal":     return "Luteal"
        case "pms":        return "PMS window"
        default:           return "Cycle"
        }
    }

    static func icon(_ raw: String) -> String {
        switch raw {
        case "menstrual":  return "drop.fill"
        case "follicular": return "leaf.fill"
        case "ovulation":  return "sun.max.fill"
        case "luteal":     return "moon.fill"
        case "pms":        return "cloud.fill"
        default:           return "circle.dotted"
        }
    }

    static func accentHex(_ raw: String) -> Int {
        switch raw {
        case "menstrual":  return 0xEFA7B2
        case "follicular": return 0xC9A87A
        case "ovulation":  return 0x6E9B7B
        case "luteal":     return 0xC9A87A
        case "pms":        return 0x6F3D74
        default:           return 0x6F3D74
        }
    }

    static func tintHex(_ raw: String) -> Int {
        switch raw {
        case "menstrual":  return 0xFBE4E7
        case "follicular": return 0xF9EFE7
        case "ovulation":  return 0xDCEBDD
        case "luteal":     return 0xFAF0E8
        case "pms":        return 0xEEE7FF
        default:           return 0xEEE7FF
        }
    }
}

enum WidgetDataStore {
    static func write(_ snapshot: WidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: caelynAppGroupID) else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: widgetSnapshotKey)
        }
    }

    static func read() -> WidgetSnapshot? {
        guard
            let defaults = UserDefaults(suiteName: caelynAppGroupID),
            let data = defaults.data(forKey: widgetSnapshotKey)
        else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Remove the shared snapshot — used by the secure wipe so widgets/watch can't
    /// keep showing data after a "Delete all data".
    static func clear() {
        UserDefaults(suiteName: caelynAppGroupID)?.removeObject(forKey: widgetSnapshotKey)
    }
}
