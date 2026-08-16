import Foundation

/// Chi chiede la conferma all'utente.
enum AuthorizationMethod: Equatable, Sendable {
    /// Il pannello di Apple Pay — l'unico posto in cui esiste il doppio clic
    /// del tasto laterale, perché Apple lo riserva a sé.
    case applePay
    /// Face ID, Touch ID o codice di sblocco.
    case local(BiometryKind)

    var prompt: String {
        switch self {
        case .applePay:        return "Doppio clic sul tasto laterale per pagare"
        case .local(let kind): return kind.prompt
        }
    }
}

enum AuthorizationOutcome: Equatable, Sendable {
    case approved
    case cancelled
}

/// L'autorizzazione di un pagamento, dietro un protocollo.
///
/// È il confine che rende testabile la macchina a stati: nei test si sostituisce
/// con un doppio che approva o annulla a comando, senza Face ID né Apple Pay.
protocol PaymentAuthorizing: AnyObject {
    var method: AuthorizationMethod { get }
    func authorize(amount: Money, recipientName: String) async throws -> AuthorizationOutcome
}

/// L'autorizzatore reale.
///
/// Sceglie Apple Pay se configurato, altrimenti l'autenticazione locale. Se il
/// pannello di Apple Pay non riesce ad aprirsi, ripiega sull'autenticazione
/// locale invece di lasciare il pagamento appeso senza spiegazioni.
final class SystemPaymentAuthorizer: PaymentAuthorizing {

    private let biometrics: BiometricAuthenticating
    private let applePay: ApplePayService

    init(
        biometrics: BiometricAuthenticating = BiometricService(),
        applePay: ApplePayService = ApplePayService()
    ) {
        self.biometrics = biometrics
        self.applePay = applePay
    }

    var method: AuthorizationMethod {
        ApplePayConfiguration.isAvailable ? .applePay : .local(biometrics.availableMethod())
    }

    func authorize(amount: Money, recipientName: String) async throws -> AuthorizationOutcome {
        if ApplePayConfiguration.isAvailable {
            do {
                let outcome = try await applePay.authorize(amount: amount, recipientName: recipientName)
                return outcome == .authorized ? .approved : .cancelled
            } catch {
                // Apple Pay non si è aperto: non è un fallimento del pagamento,
                // è un canale mancante. Si prova con quello locale.
                return try await authorizeLocally(amount: amount, recipientName: recipientName)
            }
        }

        return try await authorizeLocally(amount: amount, recipientName: recipientName)
    }

    private func authorizeLocally(amount: Money, recipientName: String) async throws -> AuthorizationOutcome {
        do {
            try await biometrics.authenticate(
                reason: "Conferma il pagamento di \(amount.formatted()) a \(recipientName)"
            )
            return .approved
        } catch BiometricError.cancelled {
            return .cancelled
        }
    }
}
