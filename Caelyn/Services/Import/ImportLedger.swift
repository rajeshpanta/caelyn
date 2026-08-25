import Foundation
import OSLog

/// Remembers **where each imported value came from**, so Caelyn can tell a value
/// she typed from a value another app supplied — without adding a provenance
/// column to `CycleEntry`. Apple Health and file imports share it, which is also
/// what lets a whole import be undone later without touching anything else.
///
/// Keeping this beside the store rather than inside it is deliberate:
///   • no SwiftData schema migration, so it cannot endanger existing histories;
///   • losing it fails *safe* — with no claims on record every value looks
///     user-entered, and user-entered values are never overwritten;
///   • it holds only record IDs and field names, so it is metadata about health
///     data rather than health data itself. It is still written with file
///     protection and still purged by `SecureWipeService`.
///
/// A claim is released the moment the stored value stops matching what was
/// imported: that means she edited it by hand, and it is hers from then on.
@MainActor
final class ImportLedger {

    struct Claim: Codable, Equatable {
        /// Day key (`yyyy-MM-dd`) — stored so a claim can be resolved back to a
        /// day/field pair when all we have is a deleted record's ID.
        let dayKey: String
        let fieldKey: String
        let recordID: UUID
        let sourceBundleID: String
        let sourceName: String
        /// The value exactly as imported (`ImportObservation.Value.ledgerValue`).
        /// The comparison against this string is what detects a later user edit.
        let importedValue: String
        /// When Caelyn merged it — a local wall clock, useful for diagnostics only.
        let importedAt: Date
        /// When the *source* recorded it. This is the clock to compare against
        /// when deciding whether a different record may take a field over;
        /// `importedAt` belongs to a different timeline entirely. Optional so an
        /// older ledger still decodes rather than being discarded wholesale.
        var recordedAt: Date?
        /// Which import brought this value in. Optional for the same reason, and
        /// absent for the continuous Apple Health sync, which is not a batch
        /// anybody would want to undo as a unit.
        var batchID: UUID?
    }

    /// One completed import, kept so it can be described and undone later.
    struct Batch: Codable, Equatable, Identifiable {
        let id: UUID
        /// `ImportSourceID.rawValue`, or "appleHealth".
        let sourceID: String
        let sourceName: String
        let importedAt: Date
        /// Values written at the time. The count shown when offering to undo.
        let valuesWritten: Int
        let daysAffected: Int
    }

    static let shared = ImportLedger(fileURL: ImportLedger.defaultFileURL())

    private let fileURL: URL?
    private var claims: [String: Claim] = [:]
    private var batchList: [Batch] = []
    /// recordID → claim keys, so a deletion notification resolves in O(1).
    private var byRecord: [UUID: Set<String>] = [:]
    private var loaded = false

    private let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "importledger")

    /// `fileURL: nil` gives a purely in-memory ledger — used by tests and by the
    /// (unreachable) case where Application Support can't be resolved.
    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    // MARK: - Keys

    /// A day key is the calendar day as she experienced it — the year, month and
    /// day of `CycleEntry.date` read in her own calendar, with no timezone
    /// arithmetic on top.
    ///
    /// Built from components rather than a `DateFormatter` for two reasons: a
    /// shared formatter is not thread-safe and this is called off the main actor
    /// while parsing, and going through a formatter would re-interpret the date in
    /// some zone and could slide a row onto the day before. The result is stable
    /// wherever she happens to be.
    nonisolated static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    nonisolated private static func key(dayKey: String, fieldKey: String) -> String { "\(dayKey)|\(fieldKey)" }

    // MARK: - Reads

    func claim(day: Date, field: ImportObservation.Field, calendar: Calendar = .current) -> Claim? {
        loadIfNeeded()
        return claims[Self.key(dayKey: Self.dayKey(day, calendar: calendar), fieldKey: field.ledgerKey)]
    }

    /// Every claim created by a given source record — the entry point for
    /// handling a record that was deleted at its source.
    func claims(forRecord recordID: UUID) -> [Claim] {
        loadIfNeeded()
        return (byRecord[recordID] ?? []).compactMap { claims[$0] }
    }

    /// True when this record has already been merged. Makes re-importing the same
    /// file, or re-reading the same HealthKit sample, a no-op instead of a
    /// duplicate.
    func hasSeen(recordID: UUID) -> Bool {
        loadIfNeeded()
        return byRecord[recordID] != nil
    }

    var claimCount: Int {
        loadIfNeeded()
        return claims.count
    }

    // MARK: - Writes

    func record(_ observation: ImportObservation, batchID: UUID? = nil, calendar: Calendar = .current) {
        loadIfNeeded()
        let dayKey = Self.dayKey(observation.day, calendar: calendar)
        let key = Self.key(dayKey: dayKey, fieldKey: observation.field.ledgerKey)

        // A field can only be claimed by one record at a time; drop the old
        // record's back-reference before the new one takes over.
        if let previous = claims[key] {
            byRecord[previous.recordID]?.remove(key)
            if byRecord[previous.recordID]?.isEmpty == true { byRecord[previous.recordID] = nil }
        }

        claims[key] = Claim(
            dayKey: dayKey,
            fieldKey: observation.field.ledgerKey,
            recordID: observation.recordID,
            sourceBundleID: observation.sourceBundleID,
            sourceName: observation.sourceName,
            importedValue: observation.value.ledgerValue,
            importedAt: Date(),
            recordedAt: observation.recordedAt,
            batchID: batchID
        )
        byRecord[observation.recordID, default: []].insert(key)
    }

    /// Give up the claim on a field. Called when the stored value no longer
    /// matches what was imported (she edited it), or when the field is cleared.
    func release(day: Date, field: ImportObservation.Field, calendar: Calendar = .current) {
        loadIfNeeded()
        release(key: Self.key(dayKey: Self.dayKey(day, calendar: calendar), fieldKey: field.ledgerKey))
    }

    func release(claim: Claim) {
        loadIfNeeded()
        release(key: Self.key(dayKey: claim.dayKey, fieldKey: claim.fieldKey))
    }

    private func release(key: String) {
        guard let existing = claims.removeValue(forKey: key) else { return }
        byRecord[existing.recordID]?.remove(key)
        if byRecord[existing.recordID]?.isEmpty == true { byRecord[existing.recordID] = nil }
    }

    // MARK: - Batches

    var batches: [Batch] {
        loadIfNeeded()
        return batchList.sorted { $0.importedAt > $1.importedAt }
    }

    func addBatch(_ batch: Batch) {
        loadIfNeeded()
        batchList.append(batch)
    }

    func removeBatch(id: UUID) {
        loadIfNeeded()
        batchList.removeAll { $0.id == id }
    }

    /// Every claim an import created that Caelyn still owns. The basis of undo:
    /// anything missing from here is either gone already or hers now, and either
    /// way undo must not touch it.
    func claims(inBatch batchID: UUID) -> [Claim] {
        loadIfNeeded()
        return claims.values.filter { $0.batchID == batchID }
    }

    func removeAll() {
        claims = [:]
        byRecord = [:]
        batchList = []
        loaded = true
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    /// On-disk shape. A bare `[String: Claim]` map was the original format;
    /// `loadIfNeeded` still accepts it so an existing ledger keeps its provenance
    /// instead of being thrown away on upgrade.
    private struct FileContents: Codable {
        var claims: [String: Claim]
        var batches: [Batch]
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }

        let decoder = JSONDecoder()
        if let wrapped = try? decoder.decode(FileContents.self, from: data) {
            claims = wrapped.claims
            batchList = wrapped.batches
        } else if let bare = try? decoder.decode([String: Claim].self, from: data) {
            claims = bare
        } else {
            // A corrupt ledger must never block importing. Starting empty simply
            // makes every existing value look user-entered — the safe direction.
            log.error("Import ledger unreadable; continuing with no provenance on record.")
            return
        }
        byRecord = [:]
        for (key, claim) in claims { byRecord[claim.recordID, default: []].insert(key) }
    }

    func save() {
        guard let fileURL, loaded else { return }
        do {
            let data = try JSONEncoder().encode(FileContents(claims: claims, batches: batchList))
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            log.error("Import ledger save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Throw away unsaved in-memory changes and re-read from disk. Used when a
    /// commit is rolled back, so the ledger never claims a value the store does
    /// not actually hold.
    func discardUnsavedChanges() {
        loaded = false
        claims = [:]
        byRecord = [:]
        batchList = []
        loadIfNeeded()
    }

    private static func defaultFileURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return dir.appending(path: "CaelynImportLedger.json")
    }
}
