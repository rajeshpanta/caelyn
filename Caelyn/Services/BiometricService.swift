import Foundation
import LocalAuthentication

enum BiometricKind {
    case none
    case touchID
    case faceID
    case opticID

    var displayName: String {
        switch self {
        case .none:    return "Biometrics"
        case .touchID: return "Touch ID"
        case .faceID:  return "Face ID"
        case .opticID: return "Optic ID"
        }
    }

    var icon: String {
        switch self {
        case .none, .touchID: return "touchid"
        case .faceID:         return "faceid"
        case .opticID:        return "opticid"
        }
    }
}

enum BiometricError: Error, LocalizedError {
    case notAvailable
    case userCancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notAvailable:           return "Biometric authentication isn't available on this device."
        case .userCancelled:          return "Authentication was cancelled."
        case .failed(let reason):     return reason
        }
    }
}

@MainActor
enum BiometricService {

    /// Detect what biometric kind (if any) is enrolled on this device.
    /// Used for icon/label only — not for gating the lock feature.
    static func availableKind() -> BiometricKind {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        switch context.biometryType {
        case .faceID:  return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .none:    return .none
        @unknown default: return .none
        }
    }

    /// True when the device has *any* form of authentication (biometrics or passcode).
    /// This is what gates the lock toggle — using only biometrics-only would lock users out
    /// if they later un-enroll Face ID at the iOS level.
    static var canAuthenticate: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    /// Prompt the user. Uses .deviceOwnerAuthentication so iOS automatically falls back
    /// to the device passcode if biometrics are unavailable or fail too many times. This
    /// guarantees the user can always recover access to their data.
    static func authenticate(reason: String = "Unlock Caelyn") async throws {
        let context = LAContext()

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if !success { throw BiometricError.failed("Authentication failed.") }
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .systemCancel || laError.code == .appCancel {
            throw BiometricError.userCancelled
        } catch {
            throw BiometricError.failed(error.localizedDescription)
        }
    }
}
