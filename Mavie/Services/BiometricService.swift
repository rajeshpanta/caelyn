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

    /// Detect what biometric kind is enrolled on this device.
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

    /// Whether the device can perform any biometric auth right now.
    static var isAvailable: Bool { availableKind() != .none }

    /// Prompt the user with their device's biometric. Returns success or throws.
    static func authenticate(reason: String = "Unlock Mavie") async throws {
        let context = LAContext()
        context.localizedFallbackTitle = ""

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricError.notAvailable
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
            if !success { throw BiometricError.failed("Authentication failed.") }
        } catch let laError as LAError where laError.code == .userCancel || laError.code == .systemCancel || laError.code == .appCancel {
            throw BiometricError.userCancelled
        } catch {
            throw BiometricError.failed(error.localizedDescription)
        }
    }
}
