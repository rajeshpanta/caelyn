import CloudKit
import CoreData
import Foundation
import OSLog
import SwiftData
import WidgetKit

/// Watches the mirrored store and keeps the "one entry per calendar day"
/// invariant true while records are arriving from another device.
///
/// **Why this exists.** Before 1.3, `CycleStore.dedupeSameDay` ran once, at
/// launch, which was enough when the only way to get a duplicate day was a
/// migration. CloudKit changes that: Device B can push a row for a day Device A
/// already has, and it lands *mid-session*. Without this, she would see the same
/// day twice until the next cold start — and the merge that protects her data
/// wouldn't have run yet.
///
/// The merge itself is `CycleStore`'s, unchanged: arrays union, per-symptom
/// severity takes the max, and scalars take the more recently updated value while
/// never overwriting something with nothing. Nothing here decides what to keep.
@MainActor
final class CloudSyncCoordinator {

    private let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "cloudsync")
    private var observer: NSObjectProtocol?
    private let container: ModelContainer

    /// Coalesces bursts. A single sync can deliver many records as a rapid series
    /// of notifications; deduping once at the end of the burst is both cheaper and
    /// more correct than racing each one.
    private var pendingWork: Task<Void, Never>?
    private let settleInterval: Duration = .milliseconds(400)

    init(container: ModelContainer) {
        self.container = container
    }

    /// Begin watching. Safe to call when sync is off — there simply are no remote
    /// changes to hear about, and the observer costs nothing.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.remoteChangeArrived() }
        }
        log.info("CloudSync: watching for remote changes.")
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        pendingWork?.cancel()
        pendingWork = nil
    }

    deinit { pendingWork?.cancel() }

    private func remoteChangeArrived() {
        pendingWork?.cancel()
        pendingWork = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.settleInterval)
            guard !Task.isCancelled else { return }
            self.reconcileArrivedRecords()
        }
    }

    /// Merge anything that arrived into the single row per day the rest of the app
    /// expects, then refresh the widget/watch snapshot so they cannot go stale.
    private func reconcileArrivedRecords() {
        let context = container.mainContext
        let merged = CycleStore.dedupeSameDay(in: context)
        if merged > 0 {
            log.info("CloudSync: merged \(merged, privacy: .public) same-day row(s) delivered by sync.")
        }
        // The snapshot is derived state, never an authority — but a widget showing
        // yesterday's cycle day after a sync would still look broken. Rebuilt from
        // the store, so the store stays the only source of truth.
        refreshDerivedSnapshot(from: context)
    }

    /// Rebuild the App Group snapshot the widget and watch read.
    ///
    /// This is deliberately one-way: the store is rebuilt into the snapshot, never
    /// the reverse. If the widget cache were ever allowed to write back, two
    /// synced devices would each have a second, competing authority.
    private func refreshDerivedSnapshot(from context: ModelContext) {
        let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
        let entries = (try? context.fetch(
            FetchDescriptor<CycleEntry>(sortBy: [SortDescriptor(\CycleEntry.date, order: .reverse)])
        )) ?? []
        let snapshot = WidgetSnapshotBuilder.build(
            profile: profile,
            entries: entries,
            isPro: PurchaseService.shared.isPro
        )
        WidgetDataStore.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Whether iCloud is actually usable right now, in her language rather than
/// CloudKit's.
///
/// Every case here is a *status*, never an error to show raw. `CKError` codes and
/// "CKAccountStatusNoAccount" must never reach the screen; this enum is the
/// translation layer, and the UI is only allowed to read `message`.
enum CloudAvailability: Equatable {
    case available
    /// No iCloud account signed in on the device.
    case noAccount
    /// Signed in, but iCloud is restricted (parental controls, MDM).
    case restricted
    /// Couldn't reach iCloud — offline, or Apple is having a moment.
    case unreachable

    /// What Caelyn says. Calm, specific, and never alarming: in every one of these
    /// states her history is still on the phone and still completely usable, so the
    /// copy leads with that rather than with the failure.
    var message: String {
        switch self {
        case .available:
            return "Your history is backed up to your private iCloud."
        case .noAccount:
            return "Sign in to iCloud in your iPhone's Settings to use sync. Everything you've logged is safe on this device either way."
        case .restricted:
            return "iCloud isn't available on this iPhone right now. Everything you've logged is safe on this device."
        case .unreachable:
            return "Caelyn can't reach iCloud at the moment — it'll catch up on its own. Everything you've logged is safe on this device."
        }
    }

    /// True when it is worth offering the sync switch at all.
    var canEnableSync: Bool { self == .available }
}

enum CloudAccount {

    /// Ask CloudKit how the account stands, and translate immediately.
    ///
    /// Deliberately returns `.unreachable` rather than throwing: nothing upstream
    /// should ever be in a position to render a CloudKit error.
    static func availability() async -> CloudAvailability {
        do {
            switch try await CKContainer(identifier: Persistence.cloudKitContainerID).accountStatus() {
            case .available:                    return .available
            case .noAccount:                    return .noAccount
            case .restricted:                   return .restricted
            case .couldNotDetermine:            return .unreachable
            case .temporarilyUnavailable:       return .unreachable
            @unknown default:                   return .unreachable
            }
        } catch {
            return .unreachable
        }
    }
}
