import XCTest
import SwiftData
@testable import Caelyn

/// There must be exactly one profile, and onboarding must never strand her.
///
/// **Why these exist.** Eighteen screens read `profiles.first`, which was harmless
/// while only onboarding could create a profile and onboarding ran once. 1.3
/// shipped iCloud sync, a profile is an ordinary mirrored record, and CloudKit
/// forbids the unique constraint that would have prevented a second one. With two
/// rows and no ordering, `profiles.first` is whichever SwiftData hands back — so
/// her name, theme, reminder times and Pro status could appear to change on their
/// own between launches.
@MainActor
final class ProfileStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: CycleEntry.self, UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        context = container.mainContext
    }
    override func tearDownWithError() throws { container = nil; context = nil }

    private func profiles() -> [UserProfile] {
        ((try? context.fetch(FetchDescriptor<UserProfile>())) ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - C2: one profile

    func testTwoProfilesBecomeOne() {
        let a = UserProfile(); a.createdAt = Date(timeIntervalSince1970: 1_000)
        let b = UserProfile(); b.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(a); context.insert(b)
        context.saveOrLog()

        let removed = ProfileStore.dedupe(in: context)
        XCTAssertEqual(removed, 1)
        XCTAssertEqual(profiles().count, 1, "two profile rows survived, so `profiles.first` is a coin flip")
    }

    func testTheOldestRowIsKept() {
        let a = UserProfile(); a.createdAt = Date(timeIntervalSince1970: 1_000)
        a.preferredName = "the one her other devices sync against"
        let b = UserProfile(); b.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(a); context.insert(b)
        context.saveOrLog()

        ProfileStore.dedupe(in: context)
        XCTAssertEqual(profiles().first?.createdAt, Date(timeIntervalSince1970: 1_000))
    }

    /// A second row arriving with defaults must not switch anything off.
    func testADefaultProfileCannotUndoSomethingSheTurnedOn() {
        let hers = UserProfile(); hers.createdAt = Date(timeIntervalSince1970: 1_000)
        hers.lockEnabled = true
        hers.hidePreview = true
        hers.remindPeriodStart = true
        hers.gentleModeEnabled = true
        hers.isPro = true
        hers.accountLinked = true
        hers.hasSeenAccountOffer = true
        hers.customSymptoms = ["Jaw ache"]
        hers.preferredName = "Sam"

        let blank = UserProfile(); blank.createdAt = Date(timeIntervalSince1970: 2_000)
        context.insert(hers); context.insert(blank)
        context.saveOrLog()

        ProfileStore.dedupe(in: context)
        let kept = profiles()[0]
        XCTAssertTrue(kept.lockEnabled, "App Lock was switched off by an empty second profile")
        XCTAssertTrue(kept.hidePreview)
        XCTAssertTrue(kept.remindPeriodStart)
        XCTAssertTrue(kept.gentleModeEnabled)
        XCTAssertTrue(kept.isPro, "her purchase was lost")
        XCTAssertTrue(kept.accountLinked)
        XCTAssertTrue(kept.hasSeenAccountOffer, "she would be offered the account a second time")
        XCTAssertEqual(kept.customSymptoms, ["Jaw ache"])
        XCTAssertEqual(kept.preferredName, "Sam", "she would be greeted by the wrong name, or none")
    }

    /// Settings turned on only on the *newer* row survive too.
    func testSomethingTurnedOnOnTheOtherDeviceAlsoSurvives() {
        let old = UserProfile(); old.createdAt = Date(timeIntervalSince1970: 1_000)
        let new = UserProfile(); new.createdAt = Date(timeIntervalSince1970: 2_000)
        new.ttcEnabled = true
        new.preferredName = "Sam"
        new.lastPeriodStart = Date(timeIntervalSince1970: 5_000)
        context.insert(old); context.insert(new)
        context.saveOrLog()

        ProfileStore.dedupe(in: context)
        let kept = profiles()[0]
        XCTAssertTrue(kept.ttcEnabled)
        XCTAssertEqual(kept.preferredName, "Sam")
        XCTAssertEqual(kept.lastPeriodStart, Date(timeIntervalSince1970: 5_000))
    }

    func testTheNewerAnswerWinsForSettingsThatAlwaysHoldAValue() {
        let old = UserProfile(); old.createdAt = Date(timeIntervalSince1970: 1_000)
        old.averageCycleLength = 28; old.theme = .light
        let new = UserProfile(); new.createdAt = Date(timeIntervalSince1970: 2_000)
        new.averageCycleLength = 33; new.theme = .dark
        context.insert(old); context.insert(new)
        context.saveOrLog()

        ProfileStore.dedupe(in: context)
        let kept = profiles()[0]
        XCTAssertEqual(kept.averageCycleLength, 33)
        XCTAssertEqual(kept.theme, .dark)
    }

    func testASingleProfileIsLeftCompletelyAlone() {
        let only = UserProfile()
        only.preferredName = "Sam"; only.averageCycleLength = 31; only.isPro = true
        context.insert(only)
        context.saveOrLog()

        XCTAssertEqual(ProfileStore.dedupe(in: context), 0, "a normal install must be a no-op")
        XCTAssertEqual(profiles().count, 1)
        XCTAssertEqual(profiles()[0].preferredName, "Sam")
        XCTAssertEqual(profiles()[0].averageCycleLength, 31)
        XCTAssertTrue(profiles()[0].isPro)
    }

    func testNoProfileAtAllIsAlsoFine() {
        XCTAssertEqual(ProfileStore.dedupe(in: context), 0)
    }

    func testDedupeIsIdempotent() {
        for i in 0..<3 {
            let p = UserProfile(); p.createdAt = Date(timeIntervalSince1970: Double(1_000 * (i + 1)))
            context.insert(p)
        }
        context.saveOrLog()
        XCTAssertEqual(ProfileStore.dedupe(in: context), 2)
        XCTAssertEqual(ProfileStore.dedupe(in: context), 0)
        XCTAssertEqual(profiles().count, 1)
    }

    // MARK: - C1: onboarding must never strand her

    /// A profile arriving from iCloud mid-onboarding used to make `complete` bail,
    /// which dropped her answers AND left `hasOnboarded` false — so onboarding
    /// came back on the next launch, and the one after that.
    func testFinishingOnboardingBesideASyncedProfileStillGetsHerIn() {
        let synced = UserProfile()
        synced.hasOnboarded = false
        synced.averageCycleLength = 30
        synced.preferredName = "Sam"
        context.insert(synced)
        context.saveOrLog()

        let vm = OnboardingViewModel()
        vm.cycleLength = 33
        vm.lastPeriodStart = Date(timeIntervalSince1970: 7_000)
        vm.complete(in: context)

        let p = profiles()[0]
        XCTAssertTrue(p.hasOnboarded, "she would be shown onboarding again on the next launch")
        XCTAssertEqual(profiles().count, 1, "onboarding created a second profile")
    }

    /// Her synced settings are hers, and more considered than a first-run guess.
    func testASyncedProfilesOwnSettingsAreNotOverwritten() {
        let synced = UserProfile()
        synced.averageCycleLength = 30
        synced.preferredName = "Sam"
        synced.lastPeriodStart = Date(timeIntervalSince1970: 1_000)
        synced.trackingGoals = [.period, .ovulation]
        context.insert(synced)
        context.saveOrLog()

        let vm = OnboardingViewModel()
        vm.cycleLength = 33
        vm.lastPeriodStart = Date(timeIntervalSince1970: 7_000)
        vm.trackingGoals = [.mood]
        vm.complete(in: context)

        let p = profiles()[0]
        XCTAssertEqual(p.averageCycleLength, 30, "her synced cycle length was replaced by a first-run guess")
        XCTAssertEqual(p.preferredName, "Sam")
        XCTAssertEqual(p.lastPeriodStart, Date(timeIntervalSince1970: 1_000))
        XCTAssertEqual(Set(p.trackingGoals), [.period, .ovulation])
    }

    /// But a gap in the synced profile is filled from what she just answered.
    func testWhatTheSyncedProfileDoesNotKnowIsFilledIn() {
        let synced = UserProfile()
        synced.lastPeriodStart = nil
        synced.trackingGoals = []
        context.insert(synced)
        context.saveOrLog()

        let vm = OnboardingViewModel()
        vm.lastPeriodStart = Date(timeIntervalSince1970: 7_000)
        vm.trackingGoals = [.mood, .pms]
        vm.enableLock = true
        vm.complete(in: context)

        let p = profiles()[0]
        XCTAssertEqual(p.lastPeriodStart, Date(timeIntervalSince1970: 7_000))
        XCTAssertEqual(Set(p.trackingGoals), [.mood, .pms])
        XCTAssertTrue(p.lockEnabled)
    }

    /// The ordinary first run is untouched.
    func testAFirstRunStillCreatesHerProfileNormally() {
        let vm = OnboardingViewModel()
        vm.cycleLength = 31
        vm.periodLength = 6
        vm.lastPeriodStart = Date(timeIntervalSince1970: 7_000)
        vm.complete(in: context)

        XCTAssertEqual(profiles().count, 1)
        let p = profiles()[0]
        XCTAssertTrue(p.hasOnboarded)
        XCTAssertEqual(p.averageCycleLength, 31)
        XCTAssertEqual(p.averagePeriodLength, 6)
        XCTAssertEqual(p.lastPeriodStart, Date(timeIntervalSince1970: 7_000))
    }
}
