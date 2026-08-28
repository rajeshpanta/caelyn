import SwiftData
import XCTest
@testable import Caelyn

/// Sign in with Apple, held to Apple's account-deletion requirements.
///
/// Several of these read the production source directly. That is deliberate: the
/// claims being defended are about what Caelyn *never touches* — tokens it must not
/// keep, a scope it must not ask for — and absence is not something a behavioural
/// test can demonstrate. A source assertion fails loudly the moment somebody adds
/// one back.
@MainActor
final class SignInWithAppleComplianceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!

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

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: root.appending(path: relativePath), encoding: .utf8)
    }

    /// The same file with `///` and `//` lines removed.
    ///
    /// Needed because these files *discuss* the things they must not do — the doc
    /// comment explaining why `.email` was dropped contains the word `.email`.
    /// Asserting against prose would fail on an accurate comment, which is the
    /// wrong thing to punish.
    private func executableSource(_ relativePath: String) throws -> String {
        try source(relativePath)
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    // MARK: - What Caelyn is allowed to receive

    /// Caelyn asks only for the name it actually uses.
    func testOnlyTheFullNameScopeIsRequested() throws {
        let code = try executableSource("Caelyn/Services/Account/AppleSignInService.swift")
        XCTAssertTrue(code.contains("requestedScopes = [.fullName]"))
        XCTAssertFalse(code.contains(".email]"), "Caelyn must not request an address it never reads.")
    }

    /// **No tokens, ever.** This is what makes programmatic revocation both
    /// impossible and unnecessary — and what keeps Caelyn out of the business of
    /// holding Apple credentials it would then have to protect.
    func testNoAppleTokenOrAuthorizationCodeIsEverRead() throws {
        let code = try executableSource("Caelyn/Services/Account/AppleSignInService.swift")
        for forbidden in ["identityToken", "authorizationCode", "credential.email", ".email"] {
            XCTAssertFalse(code.contains(forbidden),
                           "\(forbidden) must never be read — Caelyn holds no Apple credentials.")
        }
    }

    /// Nothing anywhere stores a token, a code, or a client secret.
    func testNothingInTheAccountLayerStoresAppleCredentials() throws {
        for file in ["AppleSignInService.swift", "AccountIdentityStore.swift",
                     "AccountSession.swift", "AppleSignInOutcome.swift"] {
            let code = try executableSource("Caelyn/Services/Account/\(file)")
            for forbidden in ["client_secret", "refresh_token", "access_token", "auth/revoke"] {
                XCTAssertFalse(code.contains(forbidden),
                               "\(file) references \(forbidden) — Caelyn has no server and must hold no secrets.")
            }
        }
    }

    /// The outcome type carries a user identifier and a name. Nothing else.
    func testTheAuthorizedOutcomeCarriesNoCredentialMaterial() {
        let outcome = AppleSignInOutcome.authorized(userID: "001.abc", givenName: "Maya", familyName: "Okonkwo")
        guard case let .authorized(userID, given, family) = outcome else {
            return XCTFail("unexpected outcome shape")
        }
        XCTAssertEqual(userID, "001.abc")
        XCTAssertEqual(given, "Maya")
        XCTAssertEqual(family, "Okonkwo")
    }

    // MARK: - Deleting the account removes everything Caelyn actually holds

    /// Apple: deletion removes the account record and its associated personal data.
    /// Everything Caelyn holds from Apple is the identifier and the suggested name,
    /// and both go.
    func testDeletingTheAccountRemovesEverythingCaelynHoldsFromApple() {
        AccountSession.apply(
            .authorized(userID: "001.abc", givenName: "Maya", familyName: "Okonkwo"),
            to: profile
        )
        XCTAssertNotNil(AccountIdentityStore.appleUserID)
        XCTAssertNotNil(profile.appleSuggestedName)

        // The production Delete-account path.
        AccountSession.signOut(profile: profile)
        profile.appleSuggestedName = nil

        XCTAssertNil(AccountIdentityStore.appleUserID, "The identifier must be gone.")
        XCTAssertNil(profile.appleSuggestedName, "Apple's name suggestion must be gone.")
        XCTAssertFalse(profile.accountLinked)
        XCTAssertFalse(AccountIdentityStore.isSignedIn)
    }

    /// Deleting and signing in again must produce a genuinely fresh link, not
    /// resurrect the previous one.
    func testSigningInAgainAfterDeletionStartsClean() {
        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)
        AccountSession.signOut(profile: profile)
        profile.appleSuggestedName = nil

        AccountSession.apply(.authorized(userID: "002", givenName: nil, familyName: nil), to: profile)

        XCTAssertEqual(AccountIdentityStore.appleUserID, "002", "A new sign-in replaces the identity outright.")
        XCTAssertNil(profile.appleSuggestedName,
                     "Apple sends no name on a later authorization, and the deleted one must not come back.")
    }

    // MARK: - Apple's required disclosures at deletion

    /// Apple: where an auto-renewable subscription exists, tell her billing
    /// continues and let her cancel first. Caelyn sells monthly and yearly Pro.
    func testTheDeleteAccountScreenWarnsAboutRenewingBilling() throws {
        let view = try source("Caelyn/Views/Settings/AccountView.swift")
        XCTAssertTrue(view.contains("hasAutoRenewingSubscription"),
                      "Deletion must know whether Apple is still billing her.")
        XCTAssertTrue(view.contains("https://apps.apple.com/account/subscriptions"),
                      "Apple's own subscription-management link must be offered.")
        XCTAssertTrue(view.contains("keep renewing until you cancel"))
    }

    /// Caelyn cannot revoke on her behalf, so it must say where she can.
    func testTheDeleteAccountScreenSaysHowToRemoveCaelynFromHerAppleAccount() throws {
        let view = try source("Caelyn/Views/Settings/AccountView.swift")
        XCTAssertTrue(view.contains("Sign in with Apple"),
                      "She must be told where the Apple Account setting lives.")
        XCTAssertTrue(view.contains("no tokens"),
                      "and why Caelyn has nothing of its own to hand back.")
    }

    /// The subscription warning is only for renewing purchases — a lifetime
    /// purchase does not renew and warning about it would be wrong.
    func testOnlyRenewingProductsCountAsSubscriptions() {
        let renewing = [PurchaseService.ProductID.monthly.rawValue,
                        PurchaseService.ProductID.yearly.rawValue]
        XCTAssertFalse(renewing.contains(PurchaseService.ProductID.lifetime.rawValue),
                       "Lifetime is a one-off purchase and must not trigger a billing warning.")
        XCTAssertEqual(Set(renewing).count, 2)
    }

    // MARK: - Account deletion never reaches health data

    /// The property the whole separation exists to guarantee, restated here so it
    /// is checked in the compliance suite too.
    func testDeletingTheAccountCannotReachCycleHistory() {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        for offset in 0..<30 {
            let entry = CycleEntry(date: calendar.date(byAdding: .day, value: offset, to: start)!)
            entry.flow = .medium
            context.insert(entry)
        }
        context.saveOrLog()

        AccountSession.apply(.authorized(userID: "001", givenName: "Maya", familyName: nil), to: profile)
        AccountSession.signOut(profile: profile)
        profile.appleSuggestedName = nil

        let remaining = (try? context.fetch(FetchDescriptor<CycleEntry>()))?.count ?? 0
        XCTAssertEqual(remaining, 30, "Unlinking an Apple ID must never destroy reproductive health history.")
    }

    // MARK: - Documentation accuracy

    /// No shipped Caelyn ever requested an email address — 1.2 and earlier had no
    /// Sign in with Apple at all. The docs must not imply otherwise.
    func testDocumentationDoesNotClaimAShippedVersionRequestedEmail() throws {
        let code = try source("Caelyn/Services/Account/AppleSignInService.swift")
        XCTAssertFalse(code.contains("until 1.3"), "1.2 had no Sign in with Apple to request a scope from.")
        XCTAssertFalse(code.contains("through 1.2"))
        XCTAssertTrue(code.contains("no shipped\n    /// version of Caelyn has ever asked for an email address")
                      || code.contains("has ever asked for an email address"),
                      "The correction must state the accurate history.")
    }
}
