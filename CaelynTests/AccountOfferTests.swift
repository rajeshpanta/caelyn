import SwiftData
import XCTest
@testable import Caelyn

/// How the account offer is *presented*, and whether the name it collects ever
/// reaches the field she can see.
///
/// These exist because of a bug found by tapping Sign in with Apple on a real
/// phone, which the whole automated suite had missed: she authorised with Face ID,
/// was dropped straight onto the home screen, and was never asked her name. The
/// existing offer tests could not have caught it — they re-implemented the rule
/// and checked the copy, while the fault was in how `RootView` consumed it.
@MainActor
final class AccountOfferPresentationTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        profile = UserProfile()
        profile.hasOnboarded = true
        context.insert(profile)
        AccountIdentityStore.signOut()
    }

    override func tearDownWithError() throws {
        AccountIdentityStore.signOut()
        container = nil; context = nil; profile = nil
    }

    func testNoProfileMeansNoOffer() {
        XCTAssertFalse(AccountOfferPolicy.isDue(for: nil),
                       "A nil profile has nowhere to record a name, so the offer would be a dead end.")
    }

    // MARK: - The regression: signing in must not retract the offer

    /// The trap, stated plainly: a successful sign-in makes the offer stop being
    /// "due". Anything presenting the sheet straight from this condition therefore
    /// dismisses it at exactly the wrong moment.
    func testSigningInMakesTheOfferConditionGoFalse() {
        XCTAssertTrue(AccountOfferPolicy.isDue(for: profile))
        AccountSession.apply(.authorized(userID: "u1", givenName: "Maya", familyName: "Okonkwo"), to: profile)
        XCTAssertFalse(AccountOfferPolicy.isDue(for: profile),
                       "accountLinked flips true, so the raw condition goes false mid-flow.")
    }

    /// And the fix: the raise-only latch `RootView` now uses. The sheet must still
    /// be up after sign-in, because the name step runs next.
    func testRaiseOnlyLatchSurvivesSignIn() {
        var isOffering = false
        func settle() { if AccountOfferPolicy.isDue(for: profile) { isOffering = true } }

        settle()
        XCTAssertTrue(isOffering, "The offer should have been raised.")

        AccountSession.apply(.authorized(userID: "u1", givenName: "Maya", familyName: nil), to: profile)
        settle()   // re-evaluating must never lower it

        XCTAssertTrue(isOffering,
                      "Signing in tore the sheet down and the name was never asked. It must stay up.")
        XCTAssertTrue(AccountSession.needsNameConfirmation(profile),
                      "…and the name step must still be pending at that point.")
    }

    /// The offer has to survive onboarding finishing, too — that is when it is due.
    func testLatchRisesWhenOnboardingCompletes() {
        profile.hasOnboarded = false
        var isOffering = false
        func settle() { if AccountOfferPolicy.isDue(for: profile) { isOffering = true } }

        settle()
        XCTAssertFalse(isOffering)

        profile.hasOnboarded = true
        settle()
        XCTAssertTrue(isOffering, "A latch that only ever read launch state would never offer at all.")
    }

    // MARK: - The name actually reaching the field

    func testApplesSuggestionIsCapturedAtSignIn() {
        AccountSession.apply(.authorized(userID: "u1", givenName: "Maya", familyName: "Okonkwo"), to: profile)
        XCTAssertEqual(profile.appleSuggestedName, "Maya")
        XCTAssertNil(profile.preferredName, "A suggestion is not a decision.")
    }

    func testSettingsFieldShowsApplesSuggestionWhileUnanswered() {
        AccountSession.apply(.authorized(userID: "u1", givenName: "Maya", familyName: "Okonkwo"), to: profile)
        XCTAssertEqual(AccountSession.nameFieldDraft(for: profile), "Maya",
                       "The captured suggestion was stored and then never shown to anyone.")
    }

    func testSettingsFieldPrefersHerOwnName() {
        profile.appleSuggestedName = "Maya"
        AccountSession.setPreferredName("Em", on: profile)
        XCTAssertEqual(AccountSession.nameFieldDraft(for: profile), "Em")
    }

    func testSettingsFieldRespectsADeliberateClear() {
        profile.appleSuggestedName = "Maya"
        AccountSession.setPreferredName("", on: profile)   // clearing is an answer
        XCTAssertEqual(AccountSession.nameFieldDraft(for: profile), "",
                       "Re-seeding from her Apple ID would overrule a choice she already made.")
    }

    func testSettingsFieldIsEmptyWithNothingToGoOn() {
        XCTAssertEqual(AccountSession.nameFieldDraft(for: profile), "")
        XCTAssertEqual(AccountSession.nameFieldDraft(for: nil), "")
    }

    /// Apple returns a name on the first authorization only. A returning user gets
    /// nils, and that must not wipe the suggestion already captured.
    func testRepeatSignInDoesNotEraseTheCapturedSuggestion() {
        AccountSession.apply(.authorized(userID: "u1", givenName: "Maya", familyName: nil), to: profile)
        AccountSession.apply(.authorized(userID: "u1", givenName: nil, familyName: nil), to: profile)
        XCTAssertEqual(profile.appleSuggestedName, "Maya")
        XCTAssertEqual(AccountSession.nameFieldDraft(for: profile), "Maya")
    }

    /// A relay address must never become a greeting, even via the field.
    func testHideMyEmailRelayNeverReachesTheField() {
        AccountSession.apply(.authorized(userID: "u1",
                                         givenName: "x7f3k2@privaterelay.appleid.com",
                                         familyName: nil), to: profile)
        XCTAssertNil(profile.appleSuggestedName)
        XCTAssertEqual(AccountSession.nameFieldDraft(for: profile), "")
    }
}
