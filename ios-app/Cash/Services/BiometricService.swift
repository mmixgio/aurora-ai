import Foundation
import LocalAuthentication

/// Il Face ID, quello vero di sistema.
///
/// Nel video la scansione del viso è il momento in cui il pagamento diventa
/// irreversibile, ed è l'unico pezzo di quella sequenza che iOS lascia fare
/// a un'app di terze parti. Qui non è una finta: si apre il Face ID di
/// sistema e senza autenticazione riuscita il denaro non parte.
enum BiometricService {

    enum BiometryKind {
        case faceID
        case touchID
        case passcodeOnly
        /// Nessuna forma di autenticazione configurata sul dispositivo.
        /// Non si chiama `none` di proposito: un caso con quel nome manda
        /// in confusione il compilatore con `Optional.none`.
        case unavailable

        var label: String {
            switch self {
            case .faceID: return "Face ID"
            case .touchID: return "Touch ID"
            case .passcodeOnly: return "Codice"
            case .unavailable: return "Nessuna autenticazione"
            }
        }
    }

    enum AuthenticationError: LocalizedError {
        case cancelled
        case unavailable
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .cancelled: return "Autenticazione annullata"
            case .unavailable: return "Autenticazione non disponibile su questo dispositivo"
            case .failed(let reason): return reason
            }
        }
    }

    /// Che tipo di autenticazione può usare questo iPhone.
    static func availableBiometry() -> BiometryKind {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID: return .faceID
            case .touchID: return .touchID
            default: return .passcodeOnly
            }
        }

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .passcodeOnly
        }
        return .unavailable
    }

    /// Chiede l'autenticazione e restituisce solo se è andata a buon fine.
    ///
    /// Se il dispositivo non ha la biometria (o è stata disattivata) ricade
    /// sul codice di sblocco invece di bloccare del tutto il pagamento.
    static func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Annulla"

        var error: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
            ? .deviceOwnerAuthenticationWithBiometrics
            : .deviceOwnerAuthentication

        guard context.canEvaluatePolicy(policy, error: &error) else {
            throw AuthenticationError.unavailable
        }

        // `evaluatePolicy` richiama il blocco su una coda di sistema:
        // il `continuation` riporta il risultato nel mondo async/await.
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(policy, localizedReason: reason) { success, evaluationError in
                if success {
                    continuation.resume()
                    return
                }

                let laError = evaluationError as? LAError
                switch laError?.code {
                case .userCancel?, .appCancel?, .systemCancel?:
                    continuation.resume(throwing: AuthenticationError.cancelled)
                case .biometryNotAvailable?, .biometryNotEnrolled?:
                    continuation.resume(throwing: AuthenticationError.unavailable)
                default:
                    let message = evaluationError?.localizedDescription ?? "Autenticazione non riuscita"
                    continuation.resume(throwing: AuthenticationError.failed(message))
                }
            }
        }
    }
}
