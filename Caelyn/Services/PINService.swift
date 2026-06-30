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

    static func setPIN(_ pin: String) {
        let salt = ensureSalt()
        store(Account.primary, hash(pin, salt: salt))
        resetAttempts()
    }

    /// Set or clear the duress PIN (pass nil to remove it).
    static func setDuressPIN(_ pin: String?) {
        guard let pin, !pin.isEmpty else { delete(Account.duress); return }
        let salt = ensureSalt()
        store(Account.duress, hash(pin, salt: salt))
    }

    static func clearAll() {
        delete(Account.primary); delete(Account.duress); delete(Account.salt)
        resetAttempts()
    }

    // MARK: - Verify

    static func verify(_ pin: String, now: Date = .now) -> Verdict {
        if let until = lockoutUntil(), until > now {
            return .lockedOut(retryAfter: until.timeIntervalSince(now))
        }
        guard let salt = keychainData(Account.salt) else { return .wrong(remaining: maxAttempts) }
        let candidate = hash(pin, salt: salt)
        if let primary = keychainData(Account.primary), candidate == primary {
            resetAttempts(); return .correct
        }
        if let duress = keychainData(Account.duress), candidate == duress {
            resetAttempts(); return .duress
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
