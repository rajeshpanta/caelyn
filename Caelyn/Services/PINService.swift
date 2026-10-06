import Foundation
import CryptoKit
import Security

/// App-managed numeric PIN, stored as a salted SHA-256 hash in the Keychain
/// (this-device-only, never synced). Supports an optional **duress PIN** that,
/// when entered, silently triggers a complete wipe instead of unlocking, and a
/// throttled lockout after repeated wrong attempts (Phase 5 / priv-2 + priv-3).
///
/// The raw PIN is never stored. Hashing is a pure, unit-tested function; the
/// Keychain + lockout bookkeeping is side-effecting.
enum PINService {

    private static let service = "com.caelyn.pin"
    private enum Account { static let primary = "primary"; static let duress = "duress"; static let salt = "salt" }
    private enum Defaults { static let failCount = "caelyn.pin.failCount"; static let lockoutUntil = "caelyn.pin.lockoutUntil" }

    static let maxAttempts = 5
    static let lockoutSeconds: TimeInterval = 60

    enum Verdict: Equatable {
        case correct
        case duress
        case wrong(remaining: Int)
        case lockedOut(retryAfter: TimeInterval)
    }

    // MARK: - State

    static var isSet: Bool { keychainData(Account.primary) != nil }
    static var hasDuress: Bool { keychainData(Account.duress) != nil }

    // MARK: - Configure

    /// Set her normal PIN. Refused — returns `false` — when it equals the duress
    /// PIN.
    ///
    /// `verify` checks the duress PIN first, so a normal PIN that matches it is
    /// not a normal PIN at all: the next ordinary unlock would silently erase
    /// everything. Enforced here and not only on the setup screen, so no other
    /// caller can arm that.
    @discardableResult
    static func setPIN(_ pin: String) -> Bool {
        guard !matches(pin, duress: true) else { return false }
        let salt = ensureSalt()
        store(Account.primary, hash(pin, salt: salt))
        resetAttempts()
        return true
    }

    /// Set or clear the duress PIN (pass nil to remove it). Refused — returns
    /// `false` — when it equals her normal PIN, for the same reason as `setPIN`.
    @discardableResult
    static func setDuressPIN(_ pin: String?) -> Bool {
        guard let pin, !pin.isEmpty else { delete(Account.duress); return true }
        guard !matches(pin, duress: false) else { return false }
        let salt = ensureSalt()
        store(Account.duress, hash(pin, salt: salt))
        return true
    }

    /// Whether `pin` is the stored normal (or duress) PIN — with no side effects.
    ///
    /// For setup screens checking a collision. `verify` is the wrong tool there:
    /// it counts a failed attempt for every candidate that is not a match, and
    /// during a lockout it answers `.lockedOut` instead of saying whether the
    /// digits match — so a collision check built on it could be talked past.
    static func matches(_ pin: String, duress: Bool) -> Bool {
        guard let salt = keychainData(Account.salt),
              let stored = keychainData(duress ? Account.duress : Account.primary)
        else { return false }
        return hash(pin, salt: salt) == stored
    }

    static func clearAll() {
        delete(Account.primary); delete(Account.duress); delete(Account.salt)
        resetAttempts()
    }

    // MARK: - Verify

    static func verify(_ pin: String, now: Date = .now) -> Verdict {
        guard let salt = keychainData(Account.salt) else { return .wrong(remaining: maxAttempts) }
        let candidate = hash(pin, salt: salt)

        // **The duress PIN is checked before the lockout, deliberately.**
        //
        // The lockout exists to stop someone brute-forcing their way *into* her
        // data. The duress PIN is not a way in — it is a way to destroy it. The
        // two need opposite treatment, and checking the lockout first gave them
        // the same: five wrong guesses by whoever is holding the phone, and the
        // emergency wipe was refused for a minute.
        //
        // Which is precisely backwards. Someone standing over her typing wrong
        // PINs is not a side case of this feature, it *is* the feature's whole
        // scenario — so the one moment the duress PIN is ever typed was the one
        // moment it would not work. She had been told it would: "entering it
        // instead of your real PIN silently and permanently erases everything".
        //
        // Nothing is weakened by the reorder. A guesser who stumbles onto the
        // duress PIN destroys the data, which is the outcome she armed it for.
        if let duress = keychainData(Account.duress), candidate == duress {
            // Clear the lockout too, so the app she is handed back carries no
            // trace that anything happened here.
            resetAttempts()
            return .duress
        }

        if let until = lockoutUntil(), until > now {
            return .lockedOut(retryAfter: until.timeIntervalSince(now))
        }
        if let primary = keychainData(Account.primary), candidate == primary {
            resetAttempts(); return .correct
        }
        return registerFailure(now: now)
    }

    // MARK: - Hashing (pure, testable)

    static func hash(_ pin: String, salt: Data) -> Data {
        var data = salt
        data.append(Data(pin.utf8))
        return Data(SHA256.hash(data: data))
    }

    // MARK: - Lockout bookkeeping

    private static func registerFailure(now: Date) -> Verdict {
        let d = UserDefaults.standard
        let count = d.integer(forKey: Defaults.failCount) + 1
        if count >= maxAttempts {
            d.set(now.addingTimeInterval(lockoutSeconds).timeIntervalSince1970, forKey: Defaults.lockoutUntil)
            d.set(0, forKey: Defaults.failCount)
            return .lockedOut(retryAfter: lockoutSeconds)
        }
        d.set(count, forKey: Defaults.failCount)
        return .wrong(remaining: maxAttempts - count)
    }

    private static func resetAttempts() {
        let d = UserDefaults.standard
        d.removeObject(forKey: Defaults.failCount)
        d.removeObject(forKey: Defaults.lockoutUntil)
    }

    private static func lockoutUntil() -> Date? {
        let t = UserDefaults.standard.double(forKey: Defaults.lockoutUntil)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    // MARK: - Keychain

    private static func ensureSalt() -> Data {
        if let existing = keychainData(Account.salt) { return existing }
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let salt = Data(bytes)
        store(Account.salt, salt)
        return salt
    }

    private static func store(_ account: String, _ data: Data) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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
