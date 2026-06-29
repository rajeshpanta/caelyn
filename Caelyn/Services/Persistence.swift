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

    /// The live SwiftData container. Caelyn is **local-only**: all data stays on
    /// this device, with no CloudKit sync and no Caelyn account. We pass
    /// `.none` explicitly so the store is deterministically local and never
    /// attempts to mirror to iCloud. (Real, opt-in private-CloudKit backup is a
    /// later phase — see docs/BUILD_PLAN.md. The store URL is unchanged, so any
    /// existing on-device data opens with zero loss.) A total failure is
    /// unrecoverable — fatalError so the crash log captures the exact error.
    /// UserDefaults flag set when the live store failed to open normally, so the
    /// UI can warn the user and point them to Export (data-inmemory-safety).
    static let storeFailedKey = "caelyn.storeFailed"

    /// How the live store actually opened — honest status for diagnostics/UI.
    enum StoreMode { case ok, recoveredFresh, inMemory }
    private(set) static var storeMode: StoreMode = .ok

    static let live: ModelContainer = {
        let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "swiftdata")
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)

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
