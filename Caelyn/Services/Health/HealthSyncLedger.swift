import Foundation
import OSLog

/// Remembers **where each imported value came from**, so Caelyn can tell a value
/// she typed from a value another app supplied — without adding a provenance
/// column to `CycleEntry`.
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
final class HealthSyncLedger {

    struct Claim: Codable, Equatable {
        /// Day key (`yyyy-MM-dd`) — stored so a claim can be resolved back to a
        /// day/field pair when all we have is a deleted record's ID.
        let dayKey: String
        let fieldKey: String
        let recordID: UUID
        let sourceBundleID: String
        let sourceName: String
        /// The value exactly as imported (`HealthObservation.Value.ledgerValue`).
        /// The comparison against this string is what detects a later user edit.
        let importedValue: String
        /// When Caelyn merged it — a local wall clock, useful for diagnostics only.
        let importedAt: Date
        /// When the *source* recorded it. This is the clock to compare against
        /// when deciding whether a different record may take a field over;
        /// `importedAt` belongs to a different timeline entirely. Optional so an
        /// older ledger still decodes rather than being discarded wholesale.
        var recordedAt: Date?
    }

    static let shared = HealthSyncLedger(fileURL: HealthSyncLedger.defaultFileURL())

    private let fileURL: URL?
    private var claims: [String: Claim] = [:]
    /// recordID → claim keys, so a deletion notification resolves in O(1).
    private var byRecord: [UUID: Set<String>] = [:]
    private var loaded = false

    private let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "healthledger")

    /// `fileURL: nil` gives a purely in-memory ledger — used by tests and by the
    /// (unreachable) case where Application Support can't be resolved.
    init(fileURL: URL?) {
        self.fileURL = fileURL
    }

    // MARK: - Keys

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Day keys are UTC-normalised on purpose. `CycleEntry.date` is a local
    /// start-of-day, so a user who travels would otherwise produce a different
    /// key for the same row and orphan its provenance.
    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        var utc = DateComponents()
        utc.year = comps.year; utc.month = comps.month; utc.day = comps.day
        utc.calendar = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)
        guard let normalized = utc.date else { return dayFormatter.string(from: date) }
        return dayFormatter.string(from: normalized)
    }

    private static func key(dayKey: String, fieldKey: String) -> String { "\(dayKey)|\(fieldKey)" }

    // MARK: - Reads

    func claim(day: Date, field: HealthObservation.Field, calendar: Calendar = .current) -> Claim? {
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

    func record(_ observation: HealthObservation, calendar: Calendar = .current) {
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
            recordedAt: observation.recordedAt
        )
        byRecord[observation.recordID, default: []].insert(key)
    }

    /// Give up the claim on a field. Called when the stored value no longer
    /// matches what was imported (she edited it), or when the field is cleared.
    func release(day: Date, field: HealthObservation.Field, calendar: Calendar = .current) {
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

    func removeAll() {
        claims = [:]
        byRecord = [:]
        loaded = true
        guard let fileURL else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Persistence

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return }
        guard let decoded = try? JSONDecoder().decode([String: Claim].self, from: data) else {
            // A corrupt ledger must never block syncing. Starting empty simply
            // makes every existing value look user-entered — the safe direction.
            log.error("Health ledger unreadable; continuing with no provenance on record.")
            return
        }
        claims = decoded
        byRecord = [:]
        for (key, claim) in decoded { byRecord[claim.recordID, default: []].insert(key) }
    }

    func save() {
        guard let fileURL, loaded else { return }
        do {
            let data = try JSONEncoder().encode(claims)
            try data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        } catch {
            log.error("Health ledger save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private static func defaultFileURL() -> URL? {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ) else { return nil }
        return dir.appending(path: "CaelynHealthLedger.json")
    }
}
