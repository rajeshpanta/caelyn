import Foundation

// ─────────────────────────────────────────────────────────────────────────────
// Shared between the Caelyn main app and CaelynWidget extension.
// Pure Foundation — no SwiftUI, no WidgetKit, no app-specific types.
// Register the App Group in developer.apple.com before first use:
//   group.smallpanta-icould.com.caelynperiodtracker
// ─────────────────────────────────────────────────────────────────────────────

let caelynAppGroupID = "group.smallpanta-icould.com.caelynperiodtracker"
private let widgetSnapshotKey = "caelynWidgetSnapshot"

/// Lightweight, Codable snapshot of the user's current cycle state.
/// Uses only primitive types so it compiles cleanly in both targets
/// without pulling in CyclePhase, PredictionEngine, or SwiftData models.
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
}

extension WidgetSnapshot {
    static func placeholder() -> WidgetSnapshot {
        WidgetSnapshot(
            cycleDay: 14,
            cycleLength: 28,
            phaseRaw: "follicular",
            phaseName: "Follicular",
            phaseIcon: "leaf.fill",
            phaseAccentHex: 0xF4E2D1,
            phaseTintHex: 0xF9EFE7,
            daysUntilPeriod: 14,
            periodWindowText: "Jul 10–15",
            upcomingLine1: "Fertile window in 3 days",
            upcomingLine2: "Period in 14 days",
            upcomingLine3: "",
            isPro: true,
            updatedAt: .now
        )
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
}
