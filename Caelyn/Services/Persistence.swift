import Foundation
import OSLog
import SwiftData

extension ModelContext {
    /// Save and log any error to the unified logging system. Used at call sites
    /// where there is no UI path to surface failure but we still want the error
    /// to land in Console.app / device logs instead of being silently swallowed.
    func saveOrLog(file: StaticString = #fileID, line: UInt = #line) {
        do {
            try save()
        } catch {
            Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "swiftdata")
                .error("SwiftData save failed at \(file, privacy: .public):\(line): \(error.localizedDescription, privacy: .public)")
        }
    }
}

@MainActor
enum Persistence {
    static let schema = Schema([CycleEntry.self, UserProfile.self])

    // MIGRATION POLICY — read before changing any @Model.
    // v1.0 ships with no explicit SchemaMigrationPlan on purpose: the app has never
    // been distributed, so every App Store install is a FRESH store of the current
    // schema — no historical `.unique`/old-schema store exists in production to
    // migrate. Additive changes rely on SwiftData lightweight migration, backstopped
    // by `preserveStoreAside` (never loses data) + `CycleStore.dedupeSameDay`.
    // The FIRST post-launch schema change that is NOT purely additive (renames,
    // type changes, constraint changes) MUST introduce a VersionedSchema +
    // SchemaMigrationPlan and be tested against a real pre-change store on device.

    /// The live SwiftData container. Caelyn is **local by default** — every entry
    /// stays on-device with no Caelyn account and no Caelyn server, ever. iCloud
    /// Sync is strictly **opt-in** (`syncEnabledKey`, off by default): when the
    /// user turns it on, the store mirrors to *their own* private CloudKit
    /// database (Apple end-to-end encrypted) — never through us. If the sync store
    /// can't open (e.g. the CloudKit capability isn't provisioned yet, or no iCloud
    /// account), we fall back to a plain local store so data always opens with zero
    /// loss. A total failure is unrecoverable — fatalError so the crash log captures
    /// the exact error.
    static let storeFailedKey = "caelyn.storeFailed"

    /// Opt-in iCloud sync flag. OFF unless the user explicitly enables it. Changing
    /// it takes effect on the next launch (the container is built once, here).
    static let syncEnabledKey = "caelyn.syncEnabled"
    static var isSyncEnabled: Bool { UserDefaults.standard.bool(forKey: syncEnabledKey) }

    /// The user's PRIVATE CloudKit container. Provisioned via Xcode → Signing &
    /// Capabilities → iCloud → CloudKit (needs the developer's account). Until then
    /// the sync path fails closed to a local store.
    static let cloudKitContainerID = "iCloud.smallpanta-icould.com.caelynperiodtracker"

    /// How the live store actually opened — honest status for diagnostics/UI.
    enum StoreMode { case ok, recoveredFresh, inMemory }
    private(set) static var storeMode: StoreMode = .ok

    static let live: ModelContainer = {
        let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "swiftdata")
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

        // 0. Opt-in sync path — mirror to the user's own private CloudKit database.
        //    On any failure (unprovisioned capability, signed-out iCloud, etc.) we
        //    fall through to the identical LOCAL store below, so data still opens.
        if isSyncEnabled {
            let syncConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
            if let container = try? ModelContainer(for: schema, configurations: [syncConfig]) {
                return container
            }
            log.warning("SwiftData: iCloud sync store failed to open — falling back to local.")
        }

        // 1. Normal path — open the on-disk store (SwiftData attempts automatic
        //    lightweight migration here for any compatible schema change).
        do {
            return try ModelContainer(for: schema, configurations: [localConfig])
        } catch {
            log.error("SwiftData: local store failed to open: \(error.localizedDescription, privacy: .public)")
        }

        // 2. Preserve the unreadable store aside (NEVER silently discard it — the
        //    user may be able to recover it / we can export it later) and try a
        //    FRESH local store so new data still persists to disk rather than
        //    living only in memory for the session (data-inmemory-safety).
        preserveStoreAside(log: log)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            storeMode = .recoveredFresh
            UserDefaults.standard.set(true, forKey: storeFailedKey)
            log.warning("SwiftData: opened a fresh local store; previous store preserved aside.")
            return container
        }

        // 3. Last resort: in-memory so the app stays alive (data won't persist).
        log.critical("SwiftData: local store unrecoverable — in-memory fallback. Data will not persist this session.")
        storeMode = .inMemory
        UserDefaults.standard.set(true, forKey: storeFailedKey)
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [memConfig])
        } catch {
            fatalError("SwiftData: even in-memory ModelContainer failed: \(error)")
        }
    }()

    /// SwiftData's default on-disk store location.
    private static func defaultStoreURL() -> URL? {
        try? FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appending(path: "default.store")
    }

    /// Rename an unreadable store (and its -shm/-wal sidecars) to `.corrupt-<ts>`
    /// so it is preserved for recovery instead of being overwritten/lost.
    private static func preserveStoreAside(log: Logger) {
        guard let url = defaultStoreURL() else { return }
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return }
        let stamp = Int(Date().timeIntervalSince1970)
        for suffix in ["", "-shm", "-wal"] {
            let src = URL(fileURLWithPath: url.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = URL(fileURLWithPath: url.path + ".corrupt-\(stamp)" + suffix)
            do { try fm.moveItem(at: src, to: dst) }
            catch { log.error("SwiftData: couldn't preserve store sidecar: \(error.localizedDescription, privacy: .public)") }
        }
        log.error("SwiftData: preserved unreadable store aside as default.store.corrupt-\(stamp).")
    }

    static let preview: ModelContainer = {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            PreviewData.populate(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create preview ModelContainer: \(error)")
        }
    }()

    /// In-memory container seeded with rich App Store screenshot data.
    static let screenshot: ModelContainer = {
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        do {
            let container = try ModelContainer(for: schema, configurations: [config])
            ScreenshotSeeder.populate(container.mainContext)
            return container
        } catch {
            fatalError("Failed to create screenshot ModelContainer: \(error)")
        }
    }()
}
