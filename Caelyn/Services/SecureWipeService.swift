import Foundation
import SwiftData
import WidgetKit

/// Orchestrates a **complete** local wipe of everything Caelyn stores. Used by
/// "Delete all data" today, and the foundation for the duress / secure-wipe
/// privacy feature later. Every storage location must be purged here, or a
/// "delete" would leave residue (Phase 5 / priv-3).
///
/// Storage locations:
///  1. SwiftData store — all CycleEntry + UserProfile rows
///  2. Pending local notifications (would otherwise fire referencing gone data)
///  3. Apple Health — only the flow/symptom/pain samples Caelyn itself wrote
///  4. App-Group widget snapshot (so widgets/watch stop showing data)
///  5. App preference flags that could leak state or re-show stale UI
@MainActor
enum SecureWipeService {

    static func wipeEverything(modelContext: ModelContext) async {
        // 1. SwiftData — batch-delete every row of each model.
        try? modelContext.delete(model: CycleEntry.self)
        try? modelContext.delete(model: UserProfile.self)
        modelContext.saveOrLog()

        // 2. Cancel all pending/legacy notifications.
        await NotificationService.cancelAll()

        // 3. Remove Caelyn-authored Apple Health samples (no-op if not connected).
        await HealthKitService.deleteAllOwnSamples()

        // 4. Clear the shared widget snapshot and force widgets/watch to refresh.
        WidgetDataStore.clear()
        WidgetCenter.shared.reloadAllTimelines()

        // 5. Reset preference flags so nothing stale is re-shown to a fresh user.
        let defaults = UserDefaults.standard
        for key in [
            "caelyn.dismissedInsights",
            "caelyn.softPaywallShown",
            Persistence.storeFailedKey
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
