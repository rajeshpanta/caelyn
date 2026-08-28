import Foundation
import OSLog
import Security

/// Where the Sign in with Apple identity lives.
///
/// The stable Apple user identifier is a credential, not history, so it is kept in
/// the Keychain rather than in SwiftData — and deliberately kept apart from the
/// cycle store, because the two are deleted for different reasons at different
/// times. Signing out clears this. It does not, and must not, touch a single
/// `CycleEntry`.
///
/// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`:
/// - *ThisDeviceOnly* so the identifier never rides an iCloud Keychain backup to a
///   device the user has not signed into.
/// - *AfterFirstUnlock* rather than *WhenUnlocked* because credential state is
///   checked on launch and on foregrounding, which can happen before the first
///   manual unlock after a reboot.
enum AccountIdentityStore {

    private static let service = "com.caelyn.account"
    private static let log = Logger(subsystem: "smallpanta-icould.com.caelynperiodtracker", category: "account")

    private enum Account {
        /// Apple's stable, team-scoped user identifier.
        static let appleUserID = "appleUserID"
    }

    // MARK: - Apple user identifier

    /// The signed-in Apple user identifier, or nil when signed out.
    static var appleUserID: String? {
        guard let data = keychainData(Account.appleUserID) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var isSignedIn: Bool { appleUserID != nil }

    /// Record the identifier Apple returned. Overwrites any previous one, which is
    /// correct: signing in as somebody else replaces the identity outright.
    static func save(appleUserID id: String) {
        guard let data = id.data(using: .utf8) else { return }
        store(Account.appleUserID, data)
    }

    /// Forget the identity. **Cycle history is untouched** — this is the whole
    /// point of keeping identity in a separate store. Sign out is not a delete.
    static func signOut() {
        delete(Account.appleUserID)
        log.info("Account: signed out; local history left intact.")
    }

    // MARK: - Keychain

    private static func store(_ account: String, _ data: Data) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private static func keychainData(_ account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var out: AnyObject?
        return SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess ? out as? Data : nil
    }

    private static func delete(_ account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as CFDictionary)
    }
}
