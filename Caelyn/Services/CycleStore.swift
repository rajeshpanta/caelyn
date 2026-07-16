import Foundation
import SwiftData

/// Enforces the "one entry per calendar day" invariant that the `.unique` store
/// constraint used to guarantee — it was removed in Phase 6 because CloudKit
/// forbids unique constraints. Provides:
///   • `entry(for:)` — the fetch-or-create funnel for writes (no duplicates), and
///   • `dedupeSameDay(in:)` — a launch-time pass that MERGES any same-day
///     duplicates that slipped in via an old store's migration or a sync race.
///
/// Merge policy: arrays are unioned, per-symptom severity takes the max, and
/// scalar fields take the value from the more-recently-updated row.
@MainActor
enum CycleStore {

    /// Merge every set of CycleEntry rows that fall on the same calendar day into a
    /// single row, keeping the richest data. Returns how many duplicate rows were
    /// removed (0 in the common case). Cheap to run on every launch.
    @discardableResult
    static func dedupeSameDay(in context: ModelContext, calendar: Calendar = .current) -> Int {
        let all = (try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []
        var byDay: [Date: CycleEntry] = [:]
        var removed = 0
        // Oldest first so the newest row wins scalar conflicts via `merge`.
        for entry in all.sorted(by: { $0.createdAt < $1.createdAt }) {
            let day = calendar.startOfDay(for: entry.date)
            if let keeper = byDay[day] {
                merge(from: entry, into: keeper)
                context.delete(entry)
                removed += 1
            } else {
                if entry.date != day { entry.date = day }   // normalize while we're here
                byDay[day] = entry
            }
        }
        if removed > 0 { context.saveOrLog() }
        return removed
    }

    /// The single funnel for creating/finding a day's entry, so no write path can
    /// introduce a duplicate.
    static func entry(for date: Date, in context: ModelContext, calendar: Calendar = .current) -> CycleEntry {
        let day = calendar.startOfDay(for: date)
        let descriptor = FetchDescriptor<CycleEntry>(predicate: #Predicate { $0.date == day })
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = CycleEntry(date: day)
        context.insert(created)
        return created
    }

    /// Merge `src` into `dst`: union arrays, max severity, and prefer the
    /// more-recently-updated row's scalar values.
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
        dst.updatedAt = max(dst.updatedAt, src.updatedAt)
    }
}
