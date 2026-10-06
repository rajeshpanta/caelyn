import CoreData
import Foundation
import OSLog

/// Whether anything has actually reached iCloud, as opposed to whether iCloud is
/// reachable and the store opened.
///
/// **Why this exists.** Caelyn told her "Your history is backed up to your
/// private iCloud" on the strength of two facts: `CKContainer.accountStatus()`
/// said she was signed in, and `Persistence.isSyncActive` said the mirrored store
/// opened. Neither one is evidence that a single record was uploaded.
///
/// The gap is not hypothetical. CloudKit keeps separate Development and
/// Production schemas, and a field that is not in Production yet — `dayKey` is
/// exactly such a field — makes every export of that record type fail. The
/// account is fine. The store opens fine. Reads and writes work fine, because the
/// store is the local one either way. Her history silently stops leaving the
/// phone, and the screen keeps saying it is backed up. The same shape covers a
/// full iCloud account, a record Apple rejects, and an account that loses access
/// mid-session.
///
/// So the claim is now made on the only evidence that supports it: an export
/// that CoreData reported as finished and successful. Until one has, Caelyn says
/// it is still working on it — which is true, costs her nothing, and is what the
/// rest of the app already does rather than overclaim.
///
/// `NSPersistentCloudKitContainer` posts these events whether the container was
/// built by CoreData or by SwiftData, so observing the notification is the whole
/// integration. Nothing here can affect what syncs; it only reports.
@MainActor
final class CloudSyncHealth: ObservableObject {

    static let shared = CloudSyncHealth()

    /// What the evidence supports saying.
    enum State: Equatable {
        /// Sync is on and nothing has reported in yet this launch.
        case waiting
        /// An import or export is in flight right now.
        case working
        /// An export finished successfully at this time. The only state in which
        /// Caelyn is entitled to use the word "backed up".
        case backedUp(Date)
        /// The last export finished and did not succeed. Her data is on the phone
        /// and safe; it is not in iCloud yet.
        case notLeaving
    }

    @Published private(set) var state: State = .waiting

    /// Survives relaunches so a cold start does not report "waiting" to someone
    /// whose history has been syncing for months. Only ever set from a successful
    /// export event.
    private static let lastExportKey = "caelyn.cloud.lastSuccessfulExport"

    private let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "cloudsync")
    private var observer: NSObjectProtocol?

    private init() {
        if let stamp = UserDefaults.standard.object(forKey: Self.lastExportKey) as? Date {
            state = .backedUp(stamp)
        }
    }

    /// Begin listening. Safe to call when sync is off — no events arrive.
    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            MainActor.assumeIsolated { self?.handle(note) }
        }
    }

    func stop() {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    private func handle(_ note: Notification) {
        guard let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event else { return }
        ingest(type: event.type, succeeded: event.succeeded, endDate: event.endDate,
               errorText: event.error?.localizedDescription)
    }

    /// The whole state machine, in one place. `handle` and the tests both come
    /// through here, so a test cannot pass against a copy the app does not run.
    private func ingest(type: NSPersistentCloudKitContainer.EventType,
                        succeeded: Bool,
                        endDate: Date?,
                        errorText: String?) {
        // `endDate == nil` means it has only just started. Worth showing, because
        // a first sync of a long history is not instant, but it decides nothing.
        guard endDate != nil else {
            if case .backedUp = state {} else { state = .working }
            return
        }

        switch type {
        case .export:
            if succeeded {
                let finished = endDate ?? Date()
                UserDefaults.standard.set(finished, forKey: Self.lastExportKey)
                state = .backedUp(finished)
                log.info("CloudSync: export finished successfully.")
            } else {
                state = .notLeaving
                // Logged, never shown: a CKError's text is Apple's, not Caelyn's,
                // and the copy she sees is in `message` below.
                log.error("CloudSync: export failed — \(errorText ?? "no detail", privacy: .public)")
            }

        case .setup:
            // A setup failure is how a schema that Production does not have tends
            // to surface first, and nothing will export afterwards.
            if !succeeded {
                state = .notLeaving
                log.error("CloudSync: setup failed — \(errorText ?? "no detail", privacy: .public)")
            }

        case .import:
            // An import says records came *down*, which is not evidence that hers
            // went up, so it cannot promote the state. A failure is still worth
            // saying something about rather than claiming everything is fine.
            if !succeeded {
                state = .notLeaving
                log.error("CloudSync: import failed — \(errorText ?? "no detail", privacy: .public)")
            }

        @unknown default:
            break
        }
    }

    /// Forget the last successful export. Called by everything that destroys the
    /// copy it vouched for — a wipe, or deleting the iCloud copy — because the
    /// stamp survives relaunches: turning sync back on afterwards would otherwise
    /// say "backed up … last updated" about a copy that no longer exists, before
    /// anything has been exported.
    func forget() {
        UserDefaults.standard.removeObject(forKey: Self.lastExportKey)
        state = .waiting
    }

    /// For tests: drive the state machine without CoreData.
    func ingestForTesting(type: NSPersistentCloudKitContainer.EventType,
                          succeeded: Bool,
                          endDate: Date?) {
        ingest(type: type, succeeded: succeeded, endDate: endDate, errorText: nil)
    }

    /// For tests: forget what a previous launch recorded.
    func resetForTesting() {
        UserDefaults.standard.removeObject(forKey: Self.lastExportKey)
        state = .waiting
    }
}

extension CloudSyncHealth.State {

    /// What Caelyn says, given this evidence. Calm, specific, and never naming
    /// CloudKit: in every one of these states her history is on the phone and
    /// completely usable, so the copy leads with that rather than with the
    /// failure.
    ///
    /// `availability` supplies the "signed in and reachable" half of the picture;
    /// this supplies the "and something actually arrived" half. Only `backedUp`
    /// may claim it is backed up.
    func message(availability: CloudAvailability) -> String {
        guard availability == .available else { return availability.message }
        switch self {
        case .backedUp(let when):
            let stamp = when.formatted(.relative(presentation: .named))
            return "Your history is backed up to your private iCloud. Last updated \(stamp)."
        case .working:
            return "Backing up to your private iCloud now. Everything you've logged is safe on this iPhone while it finishes."
        case .waiting:
            return "Getting ready to back up to your private iCloud. Everything you've logged is safe on this iPhone."
        case .notLeaving:
            return "Caelyn hasn't managed to finish backing up yet, and it'll keep trying. Everything you've logged is safe on this iPhone in the meantime."
        }
    }
}
