import Foundation
import HealthKit
import SwiftData

/// Orchestrates a sync: work out which types she has allowed, read them, decide
/// what changes, and — only when asked — commit.
///
/// `preview` and `apply` are separate calls over the same plan, so the app can
/// show her exactly what an import would do and let her decide. Nothing here
/// resolves a conflict on her behalf; `ImportReconciler` owns that policy
/// and this type just moves data through it.
@MainActor
enum HealthSyncService {

    enum Mode {
        /// Everything, Caelyn's own past records included. The "bring my history"
        /// path, and the only way a reinstalled app gets her history back.
        case fullImport
        /// Only what changed since the last sync, Caelyn's own writes excluded.
        case incremental

        var acceptsOwnSource: Bool { self == .fullImport }
    }

    struct Plan {
        var decisions: [ImportReconciler.Decision] = []
        var summary = ImportReconciler.Summary()
        var unreadableTypes: [String] = []
        var readResult = HealthKitReader.ReadResult()
        var types: [HKSampleType] = []
        /// Set when this plan was narrowed to one app's records.
        var sourceFilter: SourceFilter?

        var hasChanges: Bool { !summary.isEmpty }
    }

    // MARK: - Which types she has allowed

    /// Only the groups her toggles have turned on. A toggle that is off means the
    /// type is never queried, regardless of what iOS would permit.
    static func enabledTypes(for profile: UserProfile) -> [HKSampleType] {
        var groups: [HealthDataCatalog.ReadGroup] = []
        if profile.hkReadFlow { groups.append(.flow) }
        if profile.hkReadSymptoms { groups.append(.symptoms) }
        if profile.hkReadFertility { groups.append(.fertility) }
        return groups
            .flatMap(\.identifiers)
            .compactMap { $0 as? HKSampleType }
    }

    // MARK: - Preview

    /// Read Apple Health and work out what would change — without changing
    /// anything. Safe to call repeatedly.
    /// Restrict a read to one app's records.
    ///
    /// Apple Health is a shared pool: Flo, Clue, Caelyn itself and the Health app
    /// all write into it. A route that says "bring my Period Tracker history" has
    /// to mean that and nothing else, or it silently rakes in every other app's
    /// data under another app's name.
    ///
    /// The filter runs on `ImportObservation.sourceBundleID`, which HealthKit
    /// stamps from `sourceRevision.source` and no caller can forge.
    struct SourceFilter: Equatable {
        /// Bundle identifiers whose records this route accepts.
        let bundleIDs: Set<String>
        /// The app as she knows it, used in everything she reads.
        let appName: String

        /// What the resulting import is called in her list of imports.
        var label: String { "\(appName) via Apple Health" }

        /// Period Tracker by GP Apps — App Store 330376830, GP International LLC.
        /// Both identifiers are listed because the App Store build is
        /// `ptrackerlite` while the paid tier has historically shipped separately;
        /// accepting either costs nothing and missing one would silently import
        /// nothing for half its users.
        static let periodTrackerGPApps = SourceFilter(
            bundleIDs: ["com.gpapps.ptrackerlite", "com.gpapps.ptracker"],
            appName: "Period Tracker"
        )

        /// Natural Cycles — App Store 765535549, NaturalCycles Nordic AB.
        /// The app is a Cordova build, hence the identifier.
        static let naturalCycles = SourceFilter(
            bundleIDs: ["com.naturalcycles.cordova"],
            appName: "Natural Cycles"
        )
    }

    static func preview(
        mode: Mode,
        profile: UserProfile,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        limitTo sourceFilter: SourceFilter? = nil,
        calendar: Calendar = .current,
        today: Date = .now
    ) async -> Plan {
        guard HealthKitService.isAvailable, profile.healthKitConnected else { return Plan() }
        let types = enabledTypes(for: profile)
        guard !types.isEmpty else { return Plan() }

        var read = mode == .fullImport
            ? await HealthKitReader.readAll(types: types, calendar: calendar)
            : await HealthKitReader.readChanges(types: types, calendar: calendar)

        if let sourceFilter {
            read.observations = read.observations.filter { sourceFilter.bundleIDs.contains($0.sourceBundleID) }
            // Deletions are identified by record id alone, and a record from
            // another app is not this route's to clear.
            read.deletedRecordIDs = []
        }

        let lookup = valueLookup(context: context, calendar: calendar)
        let decisions = ImportReconciler.plan(
            observations: read.observations,
            deletedRecordIDs: read.deletedRecordIDs,
            currentValue: lookup,
            ledger: ledger,
            ownBundleID: Bundle.main.bundleIdentifier ?? "",
            acceptOwnSource: mode.acceptsOwnSource,
            calendar: calendar,
            today: today
        )

        var plan = Plan()
        plan.decisions = decisions
        plan.summary = ImportReconciler.summarize(decisions)
        plan.unreadableTypes = read.unreadableTypes
        plan.readResult = read
        plan.types = types
        plan.sourceFilter = sourceFilter
        return plan
    }

    /// Apply a filter to observations that have already been read. Same rule as
    /// `preview`, exposed so the behaviour can be exercised without a Health store.
    static func filtered(_ observations: [ImportObservation], by filter: SourceFilter?) -> [ImportObservation] {
        guard let filter else { return observations }
        return observations.filter { filter.bundleIDs.contains($0.sourceBundleID) }
    }

    // MARK: - Apply

    /// Commit a plan that was just previewed, then advance the anchors so the next
    /// incremental sync starts from here. Anchors move only after the merge is
    /// saved — a crash in between costs a re-read, never a lost record.
    @discardableResult
    static func apply(
        _ plan: Plan,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        batchID: UUID? = nil,
        calendar: Calendar = .current
    ) -> ImportReconciler.Summary {
        let result = ImportReconciler.commit(plan.decisions, into: context, ledger: ledger,
                                             batchID: batchID, calendar: calendar)
        // Anchors move only when the merge actually landed, and never for a
        // filtered route: it examined one app's slice, so advancing the shared
        // anchor would tell the next full sync that everything else had been seen.
        if result.succeeded, plan.sourceFilter == nil {
            HealthKitReader.commitAnchors(plan.readResult, types: plan.types)
        }
        return result.summary
    }

    /// Preview and commit in one step, for the paths that are not user-confirmed
    /// (background catch-up, and the onboarding import she already agreed to).
    @discardableResult
    static func run(
        mode: Mode,
        profile: UserProfile,
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) async -> ImportReconciler.Summary {
        let plan = await preview(mode: mode, profile: profile, context: context,
                                 ledger: ledger, calendar: calendar, today: today)
        return apply(plan, context: context, ledger: ledger, calendar: calendar)
    }

    /// The onboarding import, which runs before a `UserProfile` exists.
    ///
    /// It reads every type the permission sheet just asked about, because asking
    /// to read symptoms and fertility signals and then importing only periods
    /// would be requesting access Caelyn does not use. Caelyn's own records are
    /// accepted so a reinstall recovers her history.
    @discardableResult
    static func runInitialImport(
        context: ModelContext,
        ledger: ImportLedger = .shared,
        calendar: Calendar = .current,
        today: Date = .now
    ) async -> ImportReconciler.Summary {
        guard HealthKitService.isAvailable else { return .init() }
        let types = HealthDataCatalog.syncedSampleTypes
        let read = await HealthKitReader.readAll(types: types, calendar: calendar)
        let decisions = ImportReconciler.plan(
            observations: read.observations,
            currentValue: valueLookup(context: context, calendar: calendar),
            ledger: ledger,
            ownBundleID: Bundle.main.bundleIdentifier ?? "",
            acceptOwnSource: true,
            calendar: calendar,
            today: today
        )
        let result = ImportReconciler.commit(decisions, into: context, ledger: ledger, calendar: calendar)
        if result.succeeded { HealthKitReader.commitAnchors(read, types: types) }
        return result.summary
    }

    // MARK: - Foreground catch-up

    /// Last time a foreground sync ran, so returning to the app repeatedly does
    /// not re-scan the store each time.
    private static var lastForegroundSync: Date?
    private static let foregroundInterval: TimeInterval = 60

    /// Pick up anything that changed in Apple Health while Caelyn was away.
    ///
    /// Incremental, so it reads only what is new, and it never accepts Caelyn's
    /// own records — writing a value and reading it straight back as news is the
    /// loop this guards against. Silent by design: nothing here is worth
    /// interrupting her for, and anything it would have overwritten it leaves
    /// alone instead.
    ///
    /// Deliberately foreground-only for now. `HKObserverQuery` with background
    /// delivery would keep this current while the app is closed, but it changes
    /// when and why the app wakes up, which deserves its own review rather than
    /// arriving as a side effect of this one.
    static func syncOnForeground(now: Date = .now) async {
        if let last = lastForegroundSync, now.timeIntervalSince(last) < foregroundInterval { return }
        guard HealthKitService.isAvailable else { return }
        let context = Persistence.live.mainContext
        guard let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first,
              profile.healthKitConnected
        else { return }
        lastForegroundSync = now
        await run(mode: .incremental, profile: profile, context: context, today: now)
    }

    // MARK: - Reset

    /// Forget every anchor and every provenance claim. Called on disconnect: after
    /// it, nothing in her log is considered Caelyn-owned any more, so a later
    /// reconnect can only ever add to what she has — never overwrite it.
    static func forgetSyncState(ledger: ImportLedger = .shared) {
        HealthSyncAnchorStore.removeAll()
        ledger.removeAll()
        lastForegroundSync = nil
    }

    // MARK: - Helpers

    /// One fetch of the whole store, turned into a day-indexed lookup, so planning
    /// a multi-thousand-record import doesn't issue a query per observation.
    private static func valueLookup(
        context: ModelContext,
        calendar: Calendar
    ) -> (Date, ImportObservation.Field) -> ImportObservation.Value? {
        let entries = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        for entry in entries { byDay[calendar.startOfDay(for: entry.date)] = entry }
        return { day, field in
            byDay[calendar.startOfDay(for: day)]?.value(for: field)
        }
    }
}
