import Foundation
import HealthKit

/// Remembers how far the incremental reader got in each HealthKit type, so a sync
/// asks only "what changed since last time" instead of re-reading her whole
/// history on every launch.
///
/// Anchors are saved **after** a merge is committed, never before: if the app dies
/// mid-import the worst case is re-reading records already merged, which the
/// ledger recognises as duplicates. Losing an anchor is always safe; skipping one
/// would not be.
enum HealthSyncAnchorStore {

    private static let prefix = "caelyn.hkAnchor."

    private static func key(for type: HKSampleType) -> String { prefix + type.identifier }

    static func anchor(for type: HKSampleType) -> HKQueryAnchor? {
        guard let data = UserDefaults.standard.data(forKey: key(for: type)) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: HKQueryAnchor.self, from: data)
    }

    static func save(_ anchor: HKQueryAnchor, for type: HKSampleType) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else { return }
        UserDefaults.standard.set(data, forKey: key(for: type))
    }

    /// Forget every anchor — used on disconnect and on a full wipe, so a later
    /// reconnect starts from a clean, complete read rather than from a stale
    /// position in a history that may no longer be hers.
    static func removeAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
