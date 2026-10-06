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
    // There is still no explicit SchemaMigrationPlan, on purpose. Every schema
    // change so far has been purely additive with an inline default, which
    // SwiftData migrates automatically and which CloudKit requires anyway; adding
    // a VersionedSchema for one of those buys nothing and costs a migration plan
    // to maintain. Backstopped by `preserveStoreAside` (never loses data),
    // `CycleStore.dedupeSameDay` and `ProfileStore.dedupe`.
    //
    // Note that a new property whose value is DERIVED FROM EXISTING DATA is no
    // longer a lightweight migration. `CycleEntry.dayKey` is backfilled as
    // ordinary app code inside `dedupeSameDay`, which already walks every row at
    // launch — not in a migration stage. Do the same for the next one.
    //
    // The first change that is NOT purely additive (renames, type changes,
    // constraint changes) MUST introduce a VersionedSchema + SchemaMigrationPlan
    // and be tested against a real pre-change store on device.

    /// The live SwiftData container. Caelyn is **local first**: every entry is
    /// written to this device and never to a Caelyn server, because there is no
    /// Caelyn server. Since 1.3 she may additionally switch on a mirror to her own
    /// private CloudKit database — an extra synchronised copy, never a
    /// replacement, and off until she asks for it. A local write never waits on
    /// the network. If a store can't open we fall back so data always opens with
    /// zero loss. A total failure is unrecoverable — fatalError so the crash log
    /// captures the exact error.
    static let storeFailedKey = "caelyn.storeFailed"

    /// True when the app is running on the seeded, in-memory screenshot store.
    ///
    /// Everything that reports on storage has to know, because that container is
    /// never mirrored: it has no cloud copy and cannot acquire one. Without this,
    /// the privacy screen read the *device's* real sync preference and announced
    /// a cloud copy of data that only exists in memory — which is how an App
    /// Store capture ended up saying "because you switched on iCloud sync"
    /// underneath a headline promising it never leaves the phone.
    nonisolated static var isDemoStore: Bool {
        CommandLine.arguments.contains("--screenshot-mode")
            || CommandLine.arguments.contains("--screenshot-paywall")
            || CommandLine.arguments.contains("--ui-test-onboarding")
    }

    /// Opt-in iCloud sync flag, set from Settings → Account & iCloud since 1.3.
    /// Off by default. Changing it takes effect on the next launch, because the
    /// container is built once, here. Read `isSyncActive` — not this — when
    /// telling her anything about sync: this records what she asked for, that
    /// records what actually happened.
    static let syncEnabledKey = "caelyn.syncEnabled"
    static var isSyncEnabled: Bool { UserDefaults.standard.bool(forKey: syncEnabledKey) }

    /// Which CloudKit database Caelyn mirrors into. Only ever the user's own
    /// private one — a public database would publish reproductive health to every
    /// installation of the app. Exposed as a string so a test can assert it and
    /// fail loudly if anyone ever reaches for `.public`.
    static let syncDatabaseDescription = "private"

    /// Whether the CloudKit-backed store is the one that actually opened.
    ///
    /// **Read this, never `isSyncEnabled`, when telling her anything about sync.**
    /// The preference records what she asked for; this records what happened. A
    /// toggle that reports "syncing" while the container failed to open would be
    /// telling her that her history is backed up when it is not — the one lie a
    /// privacy-first app can never ship.
    private(set) static var isSyncActive = false

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
                // Same file on disk as the local configuration — mirroring is a
                // property of how the store syncs, not of where it lives. That is
                // why an existing user's history is simply picked up and uploaded
                // rather than replaced by an empty cloud store, and there is a test
                // pinning the two URLs together.
                isSyncActive = true
                // From here a private cloud copy is presumed to exist, and stays
                // presumed until she deletes it — switching sync off later does not
                // make the copy go away, and must not hide the button that would.
                CloudDataDeletion.noteCloudCopyMayExist()
                log.info("SwiftData: opened the iCloud-mirrored store.")
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
