import Foundation
import SwiftData

/// Keeps there being exactly one `UserProfile`.
///
/// **Why this is needed now.** Eighteen screens read `profiles.first` from an
/// unsorted `@Query`, which was harmless while only onboarding could create a
/// profile and onboarding ran once. 1.3 shipped iCloud sync, and a profile is an
/// ordinary mirrored record with no unique constraint — CloudKit forbids them —
/// so a second row can arrive: onboarding finished on a new device before the
/// first device's profile synced down, a restore landing beside a local run, a
/// merge race. With two rows and no sort, `profiles.first` is whichever SwiftData
/// hands back, which can differ between launches. Her preferred name, theme,
/// reminder times, cycle settings and Pro status would then appear to change on
/// their own, with nothing in the app to explain it.
///
/// `CycleStore.dedupeSameDay` has done this job for entries since Phase 6. This is
/// its counterpart, and runs in the same launch pass.
@MainActor
enum ProfileStore {

    /// Merge every `UserProfile` row down to one, keeping the richest answer for
    /// each setting. Returns how many rows were removed — 0 in every normal case.
    @discardableResult
    static func dedupe(in context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        guard all.count > 1 else { return 0 }

        // Oldest first: the earliest row is the one her other devices have been
        // syncing against, so it is the one to keep.
        let ordered = all.sorted { $0.createdAt < $1.createdAt }
        let keeper = ordered[0]
        for duplicate in ordered.dropFirst() {
            merge(from: duplicate, into: keeper)
            context.delete(duplicate)
        }
        context.saveOrLog()
        return ordered.count - 1
    }

    /// Fold `src` into `dst`.
    ///
    /// Additive, for the same reason the entry merge is: a second profile arriving
    /// with defaults must never blank a preference she actually set. So a `true`
    /// wins over a `false` for anything she had to switch on, a value she chose
    /// wins over a value nobody chose, and the newer row only breaks ties on the
    /// numbers that always hold a value.
    private static func merge(from src: UserProfile, into dst: UserProfile) {
        let srcNewer = src.createdAt > dst.createdAt

        // Something she had to turn on stays on.
        dst.lockEnabled              = dst.lockEnabled || src.lockEnabled
        dst.hidePreview              = dst.hidePreview || src.hidePreview
        dst.healthKitConnected       = dst.healthKitConnected || src.healthKitConnected
        dst.hkReadFlow               = dst.hkReadFlow || src.hkReadFlow
        dst.hkWriteFlow              = dst.hkWriteFlow || src.hkWriteFlow
        dst.hkReadSymptoms           = dst.hkReadSymptoms || src.hkReadSymptoms
        dst.hkWriteSymptoms          = dst.hkWriteSymptoms || src.hkWriteSymptoms
        dst.hkReadFertility          = dst.hkReadFertility || src.hkReadFertility
        dst.remindPeriodStart        = dst.remindPeriodStart || src.remindPeriodStart
        dst.remindDailyCheckIn       = dst.remindDailyCheckIn || src.remindDailyCheckIn
        dst.remindMedication         = dst.remindMedication || src.remindMedication
        dst.remindOvulation          = dst.remindOvulation || src.remindOvulation
        dst.irregularModeEnabled     = dst.irregularModeEnabled || src.irregularModeEnabled
        dst.gentleModeEnabled        = dst.gentleModeEnabled || src.gentleModeEnabled
        dst.perimenoEnabled          = dst.perimenoEnabled || src.perimenoEnabled
        dst.endoEnabled              = dst.endoEnabled || src.endoEnabled
        dst.pcosEnabled              = dst.pcosEnabled || src.pcosEnabled
        dst.ttcEnabled               = dst.ttcEnabled || src.ttcEnabled
        dst.pregnancyEnabled         = dst.pregnancyEnabled || src.pregnancyEnabled
        dst.postpartumEnabled        = dst.postpartumEnabled || src.postpartumEnabled
        dst.birthControlEnabled      = dst.birthControlEnabled || src.birthControlEnabled
        dst.birthControlReminderEnabled = dst.birthControlReminderEnabled || src.birthControlReminderEnabled
        dst.autoWipeEnabled          = dst.autoWipeEnabled || src.autoWipeEnabled
        dst.hasOnboarded             = dst.hasOnboarded || src.hasOnboarded
        dst.hasSeenAccountOffer      = dst.hasSeenAccountOffer || src.hasSeenAccountOffer
        dst.hasConfirmedPreferredName = dst.hasConfirmedPreferredName || src.hasConfirmedPreferredName
        dst.accountLinked            = dst.accountLinked || src.accountLinked
        dst.isPro                    = dst.isPro || src.isPro

        // A value she chose beats one nobody did.
        if dst.preferredName == nil        { dst.preferredName = src.preferredName }
        if dst.appleSuggestedName == nil   { dst.appleSuggestedName = src.appleSuggestedName }
        if dst.lastPeriodStart == nil      { dst.lastPeriodStart = src.lastPeriodStart }
        if dst.pregnancyDueDate == nil     { dst.pregnancyDueDate = src.pregnancyDueDate }
        if dst.postpartumBirthDate == nil  { dst.postpartumBirthDate = src.postpartumBirthDate }
        if dst.birthControlStartDate == nil { dst.birthControlStartDate = src.birthControlStartDate }
        if dst.trackingGoals.isEmpty       { dst.trackingGoals = src.trackingGoals }
        if dst.customSymptoms.isEmpty      { dst.customSymptoms = src.customSymptoms }

        // These always hold a value, so there is nothing to prefer but recency.
        if srcNewer {
            dst.averageCycleLength  = src.averageCycleLength
            dst.averagePeriodLength = src.averagePeriodLength
            dst.firstDayOfWeek      = src.firstDayOfWeek
            dst.theme               = src.theme
            dst.birthControlMethod  = src.birthControlMethod
            dst.autoWipeAfterDays   = src.autoWipeAfterDays
        }

        dst.lastActiveAt = max(dst.lastActiveAt, src.lastActiveAt)
    }
}
