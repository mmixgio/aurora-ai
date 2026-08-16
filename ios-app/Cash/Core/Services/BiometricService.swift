import Foundation
import LocalAuthentication

/// Il metodo di autenticazione che questo iPhone offre davvero.
///
/// Serve a non scrivere mai "Face ID" a schermo su un dispositivo che ha solo
/// il codice: una promessa sbagliata nell'interfaccia è un bug, non un dettaglio.
enum BiometryKind: Equatable, Sendable {
    case faceID
    case touchID
    case passcode
    case unavailable

    var label: String {
        switch self {
        case .faceID:      return "Face ID"
        case .touchID:     return "Touch ID"
        case .passcode:    return "Codice"
        case .unavailable: return "Nessuna autenticazione"
        }
    }

    /// La frase mostrata sotto il pulsante di conferma.
    var prompt: String {
        switch self {
        case .faceID:      return "Ti verrà chiesto il Face ID"
        case .touchID:     return "Ti verrà chiesto il Touch ID"
        case .passcode:    return "Ti verrà chiesto il codice"
        case .unavailable: return "Nessuna autenticazione disponibile"
        }
    }
}

enum BiometricError: Error, Equatable {
    case cancelled
    case unavailable
    case failed(String)

    var message: String {
        switch self {
        case .cancelled:      return "Autenticazione annullata"
        case .unavailable:    return "Nessuna autenticazione disponibile su questo dispositivo"
        case .failed(let why): return why
        }
    }
}

protocol BiometricAuthenticating: AnyObject, Sendable {
    func availableMethod() -> BiometryKind
    func authenticate(reason: String) async throws
}

/// L'autenticazione di sistema, via `LocalAuthentication`.
///
/// Non esiste e non deve esistere una password interna all'app: l'unica
/// autorità su chi sta usando il telefono è iOS.
final class BiometricService: BiometricAuthenticating, @unchecked Sendable {

    func availableMethod() -> BiometryKind {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:  return .faceID
            case .touchID: return .touchID
            default:       return .passcode
            }
        }

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .passcode
        }
        return .unavailable
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Annulla"

        var policyError: NSError?
        let usesBiometrics = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &policyError
        )
        let policy: LAPolicy = usesBiometrics
            ? .deviceOwnerAuthenticationWithBiometrics
            // Senza biometria si ricade sul codice di sblocco invece di
            // bloccare del tutto il pagamento.
            : .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            throw BiometricError.unavailable
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(policy, localizedReason: reason) { success, evaluationError in
                if success {
                    continuation.resume()
                    return
                }

                switch (evaluationError as? LAError)?.code {
                case .userCancel?, .appCancel?, .systemCancel?:
                    continuation.resume(throwing: BiometricError.cancelled)
                case .biometryNotAvailable?, .biometryNotEnrolled?, .passcodeNotSet?:
                    continuation.resume(throwing: BiometricError.unavailable)
                default:
                    continuation.resume(throwing: BiometricError.failed(
                        evaluationError?.localizedDescription ?? "Autenticazione non riuscita"
                    ))
                }
            }
        }
    }
}
