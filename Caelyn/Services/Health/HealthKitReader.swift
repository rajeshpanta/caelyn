import Foundation
import HealthKit
import OSLog

/// Pulls records out of Apple Health and hands them to the merge engine as
/// `HealthObservation`s. It reads and reports; it never decides and never writes.
///
/// Two modes, and the difference matters:
///
/// * **Full read** — every record of every type, Caelyn's own included. This is
///   the "bring my history" path, and including Caelyn's own past writes is the
///   point: after a reinstall they are the only copy of her history left.
/// * **Incremental read** — anchored, so it returns only what changed, plus what
///   was deleted. Caelyn's own records are filtered out downstream by the
///   reconciler, which is what stops a write from being read back as news.
@MainActor
enum HealthKitReader {

    private static let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "healthread")

    struct ReadResult {
        var observations: [HealthObservation] = []
        var deletedRecordIDs: [UUID] = []
        /// Anchors to persist once the merge is committed, keyed by type identifier.
        var anchors: [String: HKQueryAnchor] = [:]
        /// Types that could not be read. HealthKit never discloses read
        /// authorization, so this means "no data came back and it errored" —
        /// it is reported, never presented to her as a denial.
        var unreadableTypes: [String] = []
    }

    // MARK: - Full read

    /// Read everything Caelyn is interested in. One failing type never fails the
    /// batch — each is queried independently and its outcome recorded.
    static func readAll(types: [HKSampleType], calendar: Calendar = .current) async -> ReadResult {
        var result = ReadResult()
        for type in types {
            do {
                let samples = try await fetchSamples(type: type, predicate: nil)
                result.observations += samples.compactMap { HealthDataCatalog.observation(from: $0, calendar: calendar) }
            } catch {
                log.info("Couldn't read \(type.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                result.unreadableTypes.append(type.identifier)
            }
        }
        return result
    }

    // MARK: - Incremental read

    /// Read only what changed since the stored anchor for each type, including
    /// records deleted at their source.
    static func readChanges(types: [HKSampleType], calendar: Calendar = .current) async -> ReadResult {
        var result = ReadResult()
        for type in types {
            do {
                let batch = try await fetchAnchored(type: type, anchor: HealthSyncAnchorStore.anchor(for: type))
                result.observations += batch.samples.compactMap { HealthDataCatalog.observation(from: $0, calendar: calendar) }
                result.deletedRecordIDs += batch.deleted
                if let anchor = batch.newAnchor { result.anchors[type.identifier] = anchor }
            } catch {
                log.info("Couldn't sync \(type.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
                result.unreadableTypes.append(type.identifier)
            }
        }
        return result
    }

    /// Persist the anchors from a result. Call only after the merge is committed.
    static func commitAnchors(_ result: ReadResult, types: [HKSampleType]) {
        for type in types {
            guard let anchor = result.anchors[type.identifier] else { continue }
            HealthSyncAnchorStore.save(anchor, for: type)
        }
    }

    // MARK: - Queries

    private static func fetchSamples(type: HKSampleType, predicate: NSPredicate?) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: samples ?? [])
            }
            HealthKitService.sharedStore.execute(query)
        }
    }

    private struct AnchoredBatch {
        let samples: [HKSample]
        let deleted: [UUID]
        let newAnchor: HKQueryAnchor?
    }

    private static func fetchAnchored(type: HKSampleType, anchor: HKQueryAnchor?) async throws -> AnchoredBatch {
        try await withCheckedThrowingContinuation { continuation in
            // `resultsHandler` fires once for a query without an update handler,
            // so a single continuation resume is correct here.
            let query = HKAnchoredObjectQuery(
                type: type,
                predicate: nil,
                anchor: anchor,
                limit: HKObjectQueryNoLimit
            ) { _, samples, deletedObjects, newAnchor, error in
                if let error { continuation.resume(throwing: error); return }
                continuation.resume(returning: AnchoredBatch(
                    samples: samples ?? [],
                    deleted: (deletedObjects ?? []).map(\.uuid),
                    newAnchor: newAnchor
                ))
            }
            HealthKitService.sharedStore.execute(query)
        }
    }
}
