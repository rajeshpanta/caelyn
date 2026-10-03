import Foundation
import SwiftData

/// Enforces the "one entry per calendar day" invariant that the `.unique` store
/// constraint used to guarantee — it was removed in Phase 6 because CloudKit
/// forbids unique constraints. Provides:
///   • `entry(for:)` — the fetch-or-create funnel for writes (no duplicates),
///   • `dedupeSameDay(in:)` — a launch-time pass that MERGES any same-day
///     duplicates that slipped in via an old store's migration or a sync race,
///     and backfills `dayKey` on rows written before it existed.
///
/// Merge policy: arrays and per-symptom severity come from the more-recently
/// updated row, as scalars already did, so a removal she made is not undone.
@MainActor
enum CycleStore {

    /// Merge every set of CycleEntry rows that fall on the same calendar day into a
    /// single row, keeping the richest data. Returns how many duplicate rows were
    /// removed (0 in the common case). Cheap to run on every launch.
    ///
    /// Also backfills `dayKey` for any row written before that property existed.
    /// Deliberately done here, as ordinary app code, rather than in a SwiftData
    /// migration stage: deriving a new property's value *from existing data* is no
    /// longer a lightweight migration, and a custom stage would mean a
    /// VersionedSchema and a MigrationPlan for what is one pass over rows this
    /// function already walks at launch.
    @discardableResult
    static func dedupeSameDay(in context: ModelContext, calendar: Calendar = .current) -> Int {
        let all = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Int: CycleEntry] = [:]
        var removed = 0
        var backfilled = 0

        // Oldest first so the newest row wins conflicts via `merge`.
        for entry in all.sorted(by: { $0.createdAt < $1.createdAt }) {
            // A row from before `dayKey` existed is keyed to the day it currently
            // displays as, so nobody's history visibly moves on upgrade.
            if entry.dayKey == 0 {
                entry.dayKey = CivilDay.key(for: entry.date, calendar: calendar)
                backfilled += 1
            }
            let key = entry.dayKey
            if let keeper = byDay[key] {
                merge(from: entry, into: keeper)
                context.delete(entry)
                removed += 1
            } else {
                // Keep `date` consistent with the key it is filed under.
                let normalized = CivilDay.localDate(for: key, calendar: calendar)
                if entry.date != normalized { entry.date = normalized }
                byDay[key] = entry
            }
        }
        if removed > 0 || backfilled > 0 { context.saveOrLog() }
        return removed
    }

    /// The single funnel for creating/finding a day's entry, so no write path can
    /// introduce a duplicate.
    ///
    /// Matches on `dayKey` rather than on the stored instant. The old `date == day`
    /// predicate failed the moment she changed timezone — the instant it was
    /// looking for was no longer the start of any day there — and quietly created a
    /// second row for a day that already had one.
    static func entry(for date: Date, in context: ModelContext, calendar: Calendar = .current) -> CycleEntry {
        let key = CivilDay.key(for: date, calendar: calendar)
        let descriptor = FetchDescriptor<CycleEntry>(predicate: #Predicate { $0.dayKey == key })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = CycleEntry(date: date)
        // `CycleEntry.init` normalises with `Calendar.current`, which is the wrong
        // day whenever a different calendar was passed in — an import running in
        // her travel timezone, or a test pinning one. The key computed above is the
        // authority, and `date` is filed to match it.
        created.dayKey = key
        created.date = CivilDay.localDate(for: key, calendar: calendar)
        context.insert(created)
        return created
    }

    /// Merge `src` into `dst`: union arrays, max severity, and prefer the
    /// more-recently-updated row's scalar values.
    ///
    /// **The union is deliberate and must stay.** It is what makes the merge
    /// additive: a row arriving from another device holding nothing can never
    /// blank a field this device has, and cramps logged on the phone plus
    /// bloating logged on the iPad means she had both rather than whichever
    /// synced last. The cost is that a merge cannot carry a *removal* between
    /// devices — take a symptom off on one and the other's copy puts it back —
    /// and that cost is accepted on purpose: for health data, resurrecting one
    /// symptom is a smaller harm than a bad sync erasing a day she logged.
    /// `LocalFirstContractTests` and `CloudMigrationConflictTests` hold this.
    private static func merge(from src: CycleEntry, into dst: CycleEntry) {
        let srcNewer = src.updatedAt > dst.updatedAt
        func pick<T>(_ d: T?, _ s: T?) -> T? { srcNewer ? (s ?? d) : (d ?? s) }

        dst.flow               = pick(dst.flow, src.flow)
        dst.pain               = pick(dst.pain, src.pain)
        dst.mood               = pick(dst.mood, src.mood)
        dst.energyLevel        = pick(dst.energyLevel, src.energyLevel)
        dst.note               = pick(dst.note, src.note)
        dst.medication         = pick(dst.medication, src.medication)
        dst.ovulationTestResult = pick(dst.ovulationTestResult, src.ovulationTestResult)
        dst.pregnancyTest      = pick(dst.pregnancyTest, src.pregnancyTest)
        dst.cervicalMucus      = pick(dst.cervicalMucus, src.cervicalMucus)
        dst.basalTemperature   = pick(dst.basalTemperature, src.basalTemperature)
        dst.sexualActivity     = pick(dst.sexualActivity, src.sexualActivity)

        dst.painTypes            = Array(Set(dst.painTypes).union(src.painTypes))
        dst.symptoms             = Array(Set(dst.symptoms).union(src.symptoms))
        dst.loggedCustomSymptoms = Array(Set(dst.loggedCustomSymptoms).union(src.loggedCustomSymptoms))

        for (key, value) in src.symptomSeverity {
            dst.symptomSeverity[key] = max(dst.symptomSeverity[key] ?? 0, value)
        }

        // A severity is only meaningful next to the symptom it describes. The
        // union above cannot orphan one, but a row that arrived already carrying a
        // severity for a symptom it does not list can, so drop those rather than
        // keep a reading nothing is attached to.
        let named = Set(dst.symptoms.map(\.rawValue))
            .union(dst.loggedCustomSymptoms.map { "custom:\($0)" })
        dst.symptomSeverity = dst.symptomSeverity.filter { named.contains($0.key) }

        dst.updatedAt = max(dst.updatedAt, src.updatedAt)
    }
}
