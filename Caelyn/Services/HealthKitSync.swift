import Foundation
import SwiftData

/// Tiny helper that fires off a HealthKit write for a single entry **only when the
/// user has connected and turned on the corresponding write toggle**. Designed to be
/// called fire-and-forget from view code after a `modelContext.save()`.
@MainActor
enum HealthKitSync {
    static func syncIfConnected(_ entry: CycleEntry, in entries: [CycleEntry], modelContext: ModelContext) async {
        guard let profile = (try? modelContext.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        guard profile.healthKitConnected else { return }
        guard HealthKitService.isAvailable else { return }
        await HealthKitService.syncEntryToHealth(entry, in: entries, profile: profile)
    }
}
