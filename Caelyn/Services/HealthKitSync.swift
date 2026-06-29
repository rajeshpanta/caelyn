import Foundation
import SwiftData

/// Tiny helper that fires off a HealthKit write for a single entry **only when the
/// user has connected and turned on the corresponding write toggle**. Designed to be
/// called fire-and-forget from view code after a `modelContext.save()`.
///
/// Syncs are **serialized per calendar day**: `syncEntryToHealth` and the delete
/// paths do a delete-then-rewrite, so two overlapping syncs for the same date
/// (e.g. a rapid edit → delete → edit) could otherwise interleave and leave
/// duplicate or missing Health samples. Each call waits for any in-flight sync
/// for the same day before running (plat-10).
@MainActor
enum HealthKitSync {
    private static var inFlight: [Date: Task<Void, Never>] = [:]

    /// Run `work` after any in-flight operation for `day` finishes, keeping a
    /// single serialized chain per day.
    private static func serialized(on day: Date, _ work: @escaping @MainActor () async -> Void) async {
        let key = Calendar.current.startOfDay(for: day)
        let previous = inFlight[key]
        let task = Task { @MainActor in
            await previous?.value
            await work()
        }
        inFlight[key] = task
        await task.value
        if inFlight[key] == task { inFlight[key] = nil }
    }

    static func syncIfConnected(_ entry: CycleEntry, in entries: [CycleEntry], modelContext: ModelContext) async {
        guard let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        guard profile.healthKitConnected else { return }
        guard HealthKitService.isAvailable else { return }
        await serialized(on: entry.date) {
            await HealthKitService.syncEntryToHealth(entry, in: entries, profile: profile)
        }
    }

    /// Called when an entire log entry is deleted. Removes all flow, symptom,
    /// and pain samples this app wrote for that date so HealthKit stays in sync.
    static func deleteFlowIfConnected(on date: Date, modelContext: ModelContext) async {
        guard let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        guard profile.healthKitConnected, HealthKitService.isAvailable else { return }
        await serialized(on: date) {
            if profile.hkWriteFlow {
                await HealthKitService.deleteOwnFlowSamples(on: date)
            }
            if profile.hkWriteSymptoms {
                await HealthKitService.deleteOwnSymptomSamples(on: date)
            }
        }
    }
}
