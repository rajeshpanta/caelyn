import SwiftData
import XCTest
@testable import Caelyn

/// Sign in with Apple, the preferred name, and the greeting.
///
/// The thing every one of these is really testing is that an account is a
/// convenience layered on top of Caelyn, never a gate in front of it. Signing in,
/// signing out, being revoked, failing to authorize — none of them may cost her a
/// single logged day.
@MainActor
final class AccountTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        profile = UserProfile()
        context.insert(profile)
        AccountIdentityStore.signOut()   // start every test genuinely signed out
    }

    override func tearDownWithError() throws {
        AccountIdentityStore.signOut()
        container = nil; context = nil; profile = nil
    }

    private func seedHistory(days: Int = 40) {
        let start = calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        for offset in 0..<days {
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            let entry = CycleEntry(date: day, flow: offset % 28 < 4 ? .medium : nil, symptoms: [.cramps])
            entry.date = calendar.startOfDay(for: day)
            context.insert(entry)
        }
        context.saveOrLog()
    }

    private func entryCount() -> Int {
        ((try? context.fetch(FetchDescriptor<CycleEntry>())) ?? []).count
    }

    // MARK: - First sign-in

    func testFirstSignInKeepsApplesNameOnlyAsASuggestion() {
        let ok = AccountSession.apply(
            .authorized(userID: "001234.abcdef", givenName: "Maya", familyName: "Okonkwo"),
            to: profile
        )
        XCTAssertTrue(ok)
        XCTAssertEqual(AccountIdentityStore.appleUserID, "001234.abcdef")
        XCTAssertTrue(profile.accountLinked)
        XCTAssertEqual(profile.appleSuggestedName, "Maya", "The given name is the friendly one.")

        // And crucially: not yet her name. Caelyn has not asked her.
        XCTAssertNil(profile.displayName, "Apple's name must not become a greeting unasked.")
        XCTAssertTrue(AccountSession.needsNameConfirmation(profile))
    }

    /// Apple returns the name only on the very first authorization. A later
    /// sign-in returning nils must not wipe the name captured the first time.
    func testALaterSignInWithNoNameKeepsTheNameWeAlreadyHave() {
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)
        AccountSession.setPreferredName("Maya", on: profile)   // she confirmed it
        AccountSession.apply(.authorized(userID: "001", givenName: nil, familyName: nil), to: profile)

        XCTAssertEqual(profile.displayName, "Maya", "Apple only says the name once; losing it would be permanent.")
    }

    func testHerOwnNameAlwaysBeatsApples() {
        AccountSession.apply(.authorized(userID: "001", givenName: "Margaret", familyName: nil), to: profile)
        AccountSession.setPreferredName("Maya", on: profile)
        // Re-authorizing must not quietly undo her choice.
        AccountSession.apply(.authorized(userID: "001", givenName: "Margaret", familyName: nil), to: profile)

        XCTAssertEqual(profile.displayName, "Maya")
    }

    // MARK: - Hide My Email

    /// The relay address must never reach a greeting, or a profile field.
    func testHideMyEmailNeverBecomesAName() {
        AccountSession.apply(
            .authorized(userID: "001", givenName: "x7f3k2@privaterelay.appleid.com", familyName: nil),
            to: profile
        )
        XCTAssertNil(profile.displayName, "A relay address is not a name.")
        XCTAssertEqual(AccountSession.namePrefill(for: profile), "",
                       "and it must not even reach the field as a prefill.")
        XCTAssertNil(profile.appleSuggestedName)
        XCTAssertTrue(profile.accountLinked, "She is still signed in — only the name was refused.")
    }

    func testAnyAddressShapedNameIsRefused() {
        for candidate in ["maya@example.com", "  someone@somewhere.co.uk  ", "a@b"] {
            XCTAssertNil(PersonalName.usable(candidate), "\(candidate) should never be greeted by name")
        }
    }

    // MARK: - Cancellation and failure

    func testCancellingSignsNobodyInAndIsNotAnError() {
        seedHistory()
        let before = entryCount()

        let ok = AccountSession.apply(.cancelled, to: profile)

        XCTAssertFalse(ok)
        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        XCTAssertFalse(profile.accountLinked)
        XCTAssertEqual(entryCount(), before, "Backing out of sign-in cannot touch her history.")
    }

    func testAFailedAuthorizationNeverLocksHerOutOfHerOwnHistory() {
        seedHistory()
        let before = entryCount()

        AccountSession.apply(.failed(reason: "network down"), to: profile)

        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        XCTAssertEqual(entryCount(), before)
        XCTAssertGreaterThan(before, 0, "and there is genuinely history there to have kept")
    }

    // MARK: - Sign out

    func testSignOutKeepsEverySingleEntry() {
        seedHistory(days: 60)
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)
        let before = entryCount()

        AccountSession.signOut(profile: profile)

        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        XCTAssertFalse(profile.accountLinked)
        XCTAssertEqual(entryCount(), before, "Sign out is not a delete. This is the whole design.")
        XCTAssertEqual(before, 60)
    }

    /// She chose the name; it is a preference like the first day of the week. A
    /// home screen that forgets her the instant she signs out reads as data loss.
    func testSignOutKeepsTheNameSheChose() {
        AccountSession.setPreferredName("Maya", on: profile)
        AccountSession.signOut(profile: profile)
        XCTAssertEqual(profile.displayName, "Maya")
    }

    // MARK: - Credential state

    func testRevokedCredentialEndsTheSessionButNotTheHistory() {
        seedHistory()
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)
        let before = entryCount()

        let endedSession = AccountSession.reconcile(.revoked, profile: profile)

        XCTAssertTrue(endedSession)
        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        XCTAssertEqual(entryCount(), before)
    }

    /// The offline case. Apple unreachable must not look like a revocation.
    func testAnUnknownCredentialStateLeavesHerSignedIn() {
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)

        let endedSession = AccountSession.reconcile(.unknown, profile: profile)

        XCTAssertFalse(endedSession, "A train tunnel is not a revocation.")
        XCTAssertTrue(AccountIdentityStore.isSignedIn)
        XCTAssertTrue(profile.accountLinked)
    }

    func testNotFoundIsTreatedLikeRevoked() {
        XCTAssertEqual(AppleCredentialState.notFound.action, .signOutLocally)
        XCTAssertEqual(AppleCredentialState.revoked.action, .signOutLocally)
        XCTAssertEqual(AppleCredentialState.authorized.action, .staySignedIn)
        XCTAssertEqual(AppleCredentialState.unknown.action, .staySignedIn)
    }

    // MARK: - The greeting

    func testGreetingUsesHerNameWhenThereIsOne() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!
        XCTAssertEqual(HomeCopy.greeting(for: morning, name: "Maya"), "Good morning, Maya")
    }

    /// The four openers all have to read naturally with a name appended.
    func testEveryTimeOfDayGreetingReadsWellWithAName() {
        for (hour, expected) in [(9, "Good morning, Maya"), (14, "Hey there, Maya"),
                                 (19, "Good evening, Maya"), (2, "Late evening, Maya")] {
            let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: hour))!
            XCTAssertEqual(HomeCopy.greeting(for: date, name: "Maya"), expected)
        }
    }

    /// The failure mode this whole layer exists to prevent.
    func testGreetingNeverRendersAPlaceholderOrATrailingComma() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!
        for name in [nil, "", "   ", "\n", "someone@privaterelay.appleid.com", "123", "..."] as [String?] {
            let greeting = HomeCopy.greeting(for: morning, name: name)
            XCTAssertEqual(greeting, "Good morning", "Fell back badly for \(String(describing: name))")
            XCTAssertFalse(greeting.contains(","))
            XCTAssertFalse(greeting.lowercased().contains("nil"))
            XCTAssertFalse(greeting.contains("@"))
        }
    }

    func testAVeryLongNameIsDeclinedRatherThanWrappingTheHeader() {
        let long = String(repeating: "a", count: PersonalName.maxLength + 1)
        XCTAssertNil(PersonalName.usable(long))
        XCTAssertNotNil(PersonalName.usable(String(repeating: "a", count: PersonalName.maxLength)))
    }

    /// Real names contain spaces, hyphens and apostrophes and must survive intact.
    func testRealNamesAreNotMangled() {
        for name in ["Maya", "Anne-Marie", "O'Brien", "Mary Jane", "Zoë", "Aisha"] {
            XCTAssertEqual(PersonalName.usable(name), name)
        }
    }

    func testClearingTheNameReturnsToTheNamelessGreeting() {
        AccountSession.setPreferredName("Maya", on: profile)
        XCTAssertEqual(profile.displayName, "Maya")
        AccountSession.setPreferredName("   ", on: profile)
        XCTAssertNil(profile.displayName, "Blank clears rather than storing junk.")
    }

    // MARK: - Nothing here gates the app

    /// The core promise: everything works signed out.
    func testHistoryIsFullyUsableWithNoAccountAtAll() {
        seedHistory(days: 90)
        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        XCTAssertEqual(entryCount(), 90)
        XCTAssertNil(profile.displayName, "and the greeting simply stays nameless")
    }
}

/// The personalization step: Caelyn asks what to call her, once, and uses the
/// answer she gives rather than whatever is on her Apple ID.
@MainActor
final class PreferredNameStepTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!
    private let calendar = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: CycleEntry.self, UserProfile.self, configurations: config)
        context = container.mainContext
        profile = UserProfile()
        context.insert(profile)
        AccountIdentityStore.signOut()
    }

    override func tearDownWithError() throws {
        AccountIdentityStore.signOut()
        container = nil; context = nil; profile = nil
    }

    private func signIn(given: String?, family: String? = nil) {
        AccountSession.apply(.authorized(userID: "001", givenName: given, familyName: family), to: profile)
    }

    // 1. Apple provides a usable name → field is prefilled.
    func testApplesNamePrefillsTheField() {
        signIn(given: "Rajesh", family: "Panta")
        XCTAssertTrue(AccountSession.needsNameConfirmation(profile), "She should be asked.")
        XCTAssertEqual(AccountSession.namePrefill(for: profile), "Rajesh",
                       "The given name prefills — not the full legal name.")
    }

    // 2. User edits Apple's suggestion → the edit becomes the Preferred Name.
    func testEditingApplesSuggestionIsWhatCaelynUses() {
        signIn(given: "Rajesh", family: "Panta")
        AccountSession.setPreferredName("Raju", on: profile)

        XCTAssertEqual(profile.displayName, "Raju")
        XCTAssertEqual(profile.appleSuggestedName, "Rajesh", "Apple's suggestion is kept, but not used.")
        XCTAssertFalse(AccountSession.needsNameConfirmation(profile))
    }

    // 3. User accepts Apple's suggestion unchanged → it becomes the Preferred Name.
    func testAcceptingApplesSuggestionUnchangedConfirmsIt() {
        signIn(given: "Rajesh", family: "Panta")
        let prefill = AccountSession.namePrefill(for: profile)
        AccountSession.setPreferredName(prefill, on: profile)   // Continue, untouched

        XCTAssertEqual(profile.displayName, "Rajesh")
        XCTAssertFalse(AccountSession.needsNameConfirmation(profile))
    }

    // 4. Apple provides no name → the field starts empty.
    func testWithNoNameFromAppleTheFieldStartsEmpty() {
        signIn(given: nil)
        XCTAssertTrue(AccountSession.needsNameConfirmation(profile), "She is still asked.")
        XCTAssertEqual(AccountSession.namePrefill(for: profile), "",
                       "Empty — never a placeholder, never an address.")
    }

    // 5. An empty or invalid answer cannot produce an awkward greeting.
    func testAnEmptyOrInvalidAnswerNeverProducesAnAwkwardGreeting() {
        let morning = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1, hour: 9))!
        for answer in [nil, "", "   ", "\n", "someone@privaterelay.appleid.com", "123", "..."] as [String?] {
            AccountSession.setPreferredName(answer, on: profile)
            XCTAssertNil(profile.displayName, "Unusable answer should clear, not store junk: \(String(describing: answer))")

            let greeting = HomeCopy.greeting(for: morning, name: profile.displayName)
            XCTAssertEqual(greeting, "Good morning")
            XCTAssertFalse(greeting.contains(","))
            XCTAssertFalse(greeting.contains("@"))
            XCTAssertFalse(greeting.lowercased().contains("nil"))
        }
    }

    /// Choosing to have no name is a real answer, and she must not be re-asked.
    func testChoosingNoNameStillCountsAsAnswering() {
        signIn(given: "Rajesh")
        AccountSession.setPreferredName("", on: profile)

        XCTAssertNil(profile.displayName)
        XCTAssertFalse(AccountSession.needsNameConfirmation(profile),
                       "Deliberately having no name must not be nagged about.")
    }

    // 6. The confirmed name survives sign out and sign in.
    func testTheConfirmedNameSurvivesSignOutAndBackIn() {
        signIn(given: "Rajesh")
        AccountSession.setPreferredName("Raj", on: profile)

        AccountSession.signOut(profile: profile)
        XCTAssertEqual(profile.displayName, "Raj", "Signing out is not forgetting her.")

        signIn(given: nil)   // Apple sends no name the second time
        XCTAssertEqual(profile.displayName, "Raj")
    }

    // 7. A later Apple name never overwrites the confirmed Preferred Name.
    func testApplesNameOnALaterAuthorizationNeverOverwritesHerChoice() {
        signIn(given: "Rajesh")
        AccountSession.setPreferredName("Raju", on: profile)

        // A fresh authorization that does hand back a name again.
        AccountSession.apply(.authorized(userID: "001", givenName: "Rajesh", familyName: "Panta"), to: profile)

        XCTAssertEqual(profile.displayName, "Raju", "Her choice is authoritative, permanently.")
    }

    // 8. Settings can still edit it later.
    func testSettingsCanStillChangeTheNameAfterwards() {
        signIn(given: "Rajesh")
        AccountSession.setPreferredName("Raj", on: profile)

        AccountSession.setPreferredName("Rajesh", on: profile)
        XCTAssertEqual(profile.displayName, "Rajesh")

        AccountSession.setPreferredName("Raju", on: profile)
        XCTAssertEqual(profile.displayName, "Raju")
    }

    // 9. A returning user who has already answered is not asked again.
    func testAReturningUserIsNotAskedAgain() {
        signIn(given: "Rajesh")
        AccountSession.setPreferredName("Raj", on: profile)
        AccountSession.signOut(profile: profile)

        signIn(given: "Rajesh", family: "Panta")

        XCTAssertFalse(AccountSession.needsNameConfirmation(profile),
                       "She answered once; signing in again must not interrupt her.")
    }

    /// A profile arriving from another device with the answer already on it must
    /// not trigger the question here either.
    func testAProfileThatSyncedInWithAnAnswerIsNotAskedAgain() {
        profile.preferredName = "Raj"
        profile.hasConfirmedPreferredName = true

        signIn(given: "Rajesh")

        XCTAssertFalse(AccountSession.needsNameConfirmation(profile))
        XCTAssertEqual(profile.displayName, "Raj")
    }

    /// The prefill prefers a name she already has over Apple's suggestion.
    func testAnExistingNamePrefillsAheadOfApples() {
        profile.preferredName = "Raju"
        signIn(given: "Rajesh")
        XCTAssertEqual(AccountSession.namePrefill(for: profile), "Raju")
    }

    /// A brand-new user who has never signed in is not asked out of nowhere.
    func testSomeoneWhoNeverSignedInIsNeverAsked() {
        XCTAssertFalse(AccountIdentityStore.isSignedIn)
        // needsNameConfirmation is only consulted after a successful authorization;
        // nothing in the app asks otherwise, and the greeting simply stays nameless.
        XCTAssertNil(profile.displayName)
    }
}
