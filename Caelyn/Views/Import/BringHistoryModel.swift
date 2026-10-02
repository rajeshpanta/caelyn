import Foundation
import SwiftUI
import SwiftData
import Observation

/// Drives the whole "Bring your history" flow, so the screens stay presentation
/// and every rule about *when* something happens lives in one testable place.
///
/// The shape of the flow is the product promise: a file is read, she is shown
/// what it would do, and only then — if she says so — is anything written.
/// `phase` makes that literal; there is no path from `.reading` to `.done` that
/// skips `.confirming`.
@Observable
@MainActor
final class BringHistoryModel {

    enum Phase: Equatable {
        case choosingSource
        /// Reading the file. The one long step, and the only one that shows a spinner.
        case reading
        /// A preview is on screen and nothing has been written.
        case confirming
        /// She confirmed and the write is in flight. Blocks a second confirm.
        case importing
        case done(ImportOutcome)
        case failed(String)
    }

    struct ImportOutcome: Equatable {
        let batchID: UUID
        let sourceName: String
        let summary: ImportReconciler.Summary
        let spanDescription: String?
        /// Whether the batch can still be taken back.
        var undone = false
    }

    private(set) var phase: Phase = .choosingSource
    private(set) var preview: ImportPreview?

    /// The Apple Health plan behind a Health preview. Kept so applying can also
    /// advance the sync anchors, which a file import has no equivalent of.
    private var healthPlan: HealthSyncService.Plan?

    /// True when this run came from Apple Health rather than a file.
    ///
    /// The confirmation screen needs it because a Health route has no file: telling
    /// her to "choose a different file" when she never chose one is how she ends up
    /// hunting for a file picker that was never going to appear.
    var isHealthRoute: Bool { healthPlan != nil }

    private let calendar: Calendar
    private let ledger: ImportLedger

    /// How the model asks Apple Health for read access.
    ///
    /// In the app this is Apple's own permission sheet, which is the only place
    /// access can be granted. A unit-test host has no UI to present that sheet on,
    /// so `requestAuthorization` never resumes there — the continuation is simply
    /// abandoned and the whole suite stalls on whichever test called this first,
    /// with no failure and no timeout. The seam lets a test answer for it; nothing
    /// in the app ever replaces the default.
    var requestHealthReadAccess: () async throws -> Void = {
        try await HealthKitService.requestReadAuthorization()
    }

    init(calendar: Calendar = .current, ledger: ImportLedger = .shared) {
        self.calendar = calendar
        self.ledger = ledger
    }

    var isBusy: Bool { phase == .reading || phase == .importing }

    // MARK: - Reading a file

    /// Read a picked file and build a preview. Writes nothing.
    ///
    /// Security-scoped access is opened and closed around the read itself — the
    /// bytes are copied into memory before the scope ends, so nothing later in the
    /// flow depends on a URL that may no longer be reachable.
    func readFile(at url: URL, context: ModelContext, today: Date = .now) async {
        guard !isBusy else { return }
        phase = .reading

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let filename = url.lastPathComponent
        guard let data = try? Data(contentsOf: url) else {
            // Either the sandbox refused it or the file went away. Both look the
            // same from here, and both are fixed the same way.
            phase = .failed("Caelyn couldn't open that file. Try choosing it again, or save it to Files first.")
            return
        }
        await read(filename: filename, data: data, context: context, today: today)
    }

    /// Read bytes Caelyn already holds — the share-sheet route, where the file has
    /// been copied into the app's own storage before we get here.
    func read(filename: String, data: Data, context: ModelContext, today: Date = .now) async {
        phase = .reading
        guard !data.isEmpty else {
            phase = .failed(ImportSourceError.empty.errorDescription ?? "That file is empty.")
            return
        }
        do {
            let plan = try await ImportPlanner.plan(
                filename: filename, data: data, context: context,
                ledger: ledger, calendar: calendar, today: today
            )
            healthPlan = nil
            healthSourceFilter = nil
            preview = plan
            phase = .confirming
        } catch let error as ImportSourceError {
            phase = .failed(error.errorDescription ?? "Caelyn couldn't read that file.")
        } catch {
            phase = .failed("Caelyn couldn't read that file.")
        }
    }

    // MARK: - Apple Health

    /// Work out what Apple Health would add, without adding it.
    /// Set when the route narrowed to one app, so the finished import is named
    /// after that app rather than appearing as a generic Apple Health import in
    /// her list of imports.
    private var healthSourceFilter: HealthSyncService.SourceFilter?

    /// True once this run granted Apple Health access while no profile existed —
    /// i.e. during onboarding. The onboarding step reads it so the profile it
    /// creates at the end records that she connected, instead of silently
    /// forgetting and leaving her reads switched off.
    private(set) var connectedHealthWithoutProfile = false

    /// Read Apple Health and build a preview.
    ///
    /// - Parameter profile: nil during onboarding, when no `UserProfile` exists
    ///   yet. The profile is only ever consulted for *which types she has allowed*;
    ///   with no profile the scope is everything Apple's sheet just asked about, so
    ///   a new user can bring her history across before finishing onboarding. This
    ///   used to `guard let` and silently return her to the source list.
    func readAppleHealth(
        profile: UserProfile?,
        context: ModelContext,
        limitTo sourceFilter: HealthSyncService.SourceFilter? = nil,
        today: Date = .now
    ) async {
        guard !isBusy else { return }
        phase = .reading
        guard HealthKitService.isAvailable else {
            phase = .failed("Apple Health isn't available on this device.")
            return
        }
        // Ask for permission first if she hasn't connected yet; the sheet is
        // Apple's and is the only place access is granted. With no profile there is
        // nothing recording a previous connection, so we always ask — iOS shows the
        // sheet once and returns immediately thereafter.
        if profile?.healthKitConnected != true {
            do {
                try await requestHealthReadAccess()
                if let profile {
                    profile.healthKitConnected = true
                    profile.hkReadFlow = true
                    profile.hkReadSymptoms = true
                    profile.hkReadFertility = true
                    context.saveOrLog()
                } else {
                    connectedHealthWithoutProfile = true
                }
            } catch {
                phase = .failed("Caelyn couldn't reach Apple Health just now.")
                return
            }
        }

        // The read scope: her toggles when there is a profile, everything the
        // permission sheet covered when there is not.
        let types = profile.map { HealthSyncService.enabledTypes(for: $0) }
            ?? HealthDataCatalog.syncedSampleTypes

        let plan = await HealthSyncService.preview(
            mode: .fullImport, types: types, context: context,
            ledger: ledger, limitTo: sourceFilter, calendar: calendar, today: today
        )
        healthPlan = plan
        healthSourceFilter = sourceFilter
        preview = ImportPreview.fromHealth(plan, sourceFilter: sourceFilter)
        phase = .confirming
    }

    // MARK: - Confirming

    /// Write the previewed import. Guarded so a second tap while the first is in
    /// flight cannot produce a second batch.
    func confirm(context: ModelContext) {
        guard phase == .confirming, let preview else { return }
        phase = .importing

        let result: ImportReconciler.CommitResult
        if let healthPlan {
            let summary = HealthSyncService.apply(healthPlan, context: context, ledger: ledger,
                                                  batchID: preview.batchID, calendar: calendar)
            if summary.changeCount > 0 {
                ledger.addBatch(ImportLedger.Batch(
                    id: preview.batchID,
                    sourceID: ImportSourceID.appleHealth.rawValue,
                    sourceName: healthSourceFilter?.label ?? ImportSourceID.appleHealth.displayName,
                    importedAt: Date(),
                    valuesWritten: summary.changeCount,
                    daysAffected: summary.daysAffected
                ))
                ledger.save()
            }
            result = ImportReconciler.CommitResult(summary: summary, succeeded: true, failure: nil)
        } else {
            result = ImportPlanner.commit(preview, context: context, ledger: ledger, calendar: calendar)
        }

        guard result.succeeded else {
            // Nothing was written — the store was put back as it was.
            phase = .failed("Caelyn couldn't save that import, so nothing was changed. Please try again.")
            return
        }

        // Success must mean success. If everything the preview offered turned out
        // to be hers already — she logged those days while the preview was on
        // screen — nothing was added, and a "your history is here" screen over zero
        // new days would be a small lie.
        guard result.summary.changeCount > 0 else {
            phase = .failed("Nothing was added — everything in that import is already in Caelyn, exactly as you logged it.")
            return
        }

        phase = .done(ImportOutcome(
            batchID: preview.batchID,
            sourceName: healthSourceFilter?.label ?? preview.source.displayName,
            summary: result.summary,
            spanDescription: preview.spanDescription(calendar: calendar)
        ))
    }

    /// Back out before confirming. Nothing has been written, so there is nothing
    /// to undo — the preview is simply discarded.
    func cancel() {
        preview = nil
        healthPlan = nil
        healthSourceFilter = nil
        phase = .choosingSource
    }

    func dismissError() {
        phase = .choosingSource
    }

    // MARK: - Undo

    @discardableResult
    func undoLastImport(context: ModelContext) -> Bool {
        guard case .done(var outcome) = phase, !outcome.undone else { return false }
        let result = ImportPlanner.undo(batchID: outcome.batchID, context: context,
                                        ledger: ledger, calendar: calendar)
        guard result.succeeded else { return false }
        outcome.undone = true
        phase = .done(outcome)
        return true
    }
}
