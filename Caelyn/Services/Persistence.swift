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

    /// Private CloudKit container — data syncs to the user's own iCloud account,
    /// not to any Caelyn server. If the user isn't signed in to iCloud or the
    /// CloudKit container isn't provisioned yet, we fall back to local-only
    /// storage so the app stays fully functional either way.
    private static let cloudKitContainerID = "iCloud.smallpanta-icould.com.caelynperiodtracker"

    /// The live SwiftData container. Tries CloudKit first; falls back to
    /// local-only if unavailable (no iCloud account, unprovisioned container,
    /// simulator, etc.). A failure on both paths is unrecoverable — fatalError
    /// so the crash log captures the exact storage error.
    static let live: ModelContainer = {
        let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "swiftdata")

        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private(cloudKitContainerID)
        )
        if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
            log.info("SwiftData: using CloudKit-backed store")
            return container
        }

        // Fallback: local-only. CloudKit may be unavailable on this device.
        log.warning("SwiftData: CloudKit unavailable, falling back to local store")
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [localConfig]) {
            return container
        }

        // Last resort: in-memory store so the app stays alive. User data will
        // not persist this session. We log critically so the error surfaces in
        // Console.app and any attached crash reporter.
        log.critical("SwiftData: local store failed — using in-memory fallback. User data will not persist.")
        let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        do {
            return try ModelContainer(for: schema, configurations: [memConfig])
        } catch {
            fatalError("SwiftData: even in-memory ModelContainer failed: \(error)")
        }
    }()

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
}
