import Foundation
import PassKit

enum ApplePayError: Error, Equatable {
    case notConfigured
    case noCardsAvailable
    case sheetUnavailable

    var message: String {
        switch self {
        case .notConfigured:
            return "Apple Pay non è configurato in questa build"
        case .noCardsAvailable:
            return "Nessuna carta disponibile nel Wallet"
        case .sheetUnavailable:
            return "Apple Pay non si è potuto aprire"
        }
    }
}

/// La configurazione di Apple Pay.
///
/// ## Perché il codice Apple Pay JS non era applicabile
///
/// `PaymentRequest`, `onmerchantvalidation` e `validateMerchant` sono
/// **Apple Pay JS**: girano dentro Safari, su un sito. In un'app nativa non
/// esistono. L'equivalente è PassKit, che è ciò che c'è qui.
///
/// ## Cosa serve perché il pannello si apra davvero
///
/// 1. **Apple Developer Program a pagamento**: con un Apple ID gratuito non si
///    può creare un identificativo commerciante.
/// 2. Un **Merchant ID** dal portale, da incollare in `merchantIdentifier`.
/// 3. La **capacità Apple Pay** aggiunta al target, che genera l'entitlement
///    `com.apple.developer.in-app-payments`.
/// 4. Per incassare davvero, un **gestore dei pagamenti** a cui inoltrare il
///    token che Apple restituisce.
///
/// I punti 1-3 vanno insieme: l'entitlement non è gestibile dalla firma
/// gratuita, quindi aggiungerlo senza account a pagamento impedisce la
/// compilazione. Finché `merchantIdentifier` è vuoto Apple Pay resta spento e
/// la conferma passa dall'autenticazione locale.
///
/// **Apple Pay non muove il saldo di questa app.** Il saldo è e resta locale:
/// il pannello autorizza, la contabilità la fa `TransactionStore`.
enum ApplePayConfiguration {

    /// L'unica riga da toccare per accendere Apple Pay.
    static let merchantIdentifier = ""

    /// Il paese del commerciante, non quello dell'utente.
    static let countryCode = "IT"

    static let supportedNetworks: [PKPaymentNetwork] = [
        .visa, .masterCard, .amex, .maestro, .discover
    ]

    /// `threeDSecure` è il minimo richiesto da Apple per un pagamento reale.
    static let merchantCapabilities: PKMerchantCapability = [.threeDSecure]

    static var isConfigured: Bool { !merchantIdentifier.isEmpty }

    /// Serve sia l'identificativo sia almeno una carta nel Wallet: un merchant
    /// ID su un telefono senza carte aprirebbe un pannello vuoto.
    static var isAvailable: Bool {
        isConfigured
            && PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)
    }

    static func request(amount: Money, recipientName: String) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        request.merchantIdentifier = merchantIdentifier
        request.merchantCapabilities = merchantCapabilities
        request.supportedNetworks = supportedNetworks
        request.countryCode = countryCode
        request.currencyCode = AppConfiguration.currency.code
        request.paymentSummaryItems = [
            PKPaymentSummaryItem(
                label: recipientName,
                amount: amount.decimalNumber,
                type: .final
            )
        ]
        return request
    }
}

/// Presenta il pannello e attende l'esito.
///
/// PassKit parla per delegato e blocchi di completamento; questa classe li
/// traduce in una sola funzione `async`, così la macchina a stati del
/// pagamento resta leggibile dall'alto in basso.
final class ApplePayService: NSObject, PKPaymentAuthorizationControllerDelegate {

    enum Outcome: Equatable {
        case authorized
        case cancelled
    }

    private var continuation: CheckedContinuation<Outcome, Error>?
    private var controller: PKPaymentAuthorizationController?

    /// Registrato quando l'utente autorizza, restituito solo alla chiusura del
    /// pannello: `didAuthorizePayment` e `didFinish` sono momenti distinti, e
    /// rispondere troppo presto farebbe partire l'animazione mentre il
    /// pannello di Apple è ancora a schermo.
    private var pendingOutcome: Outcome = .cancelled

    func authorize(amount: Money, recipientName: String) async throws -> Outcome {
        guard ApplePayConfiguration.isConfigured else {
            throw ApplePayError.notConfigured
        }
        guard ApplePayConfiguration.isAvailable else {
            throw ApplePayError.noCardsAvailable
        }

        let request = ApplePayConfiguration.request(amount: amount, recipientName: recipientName)

        return try await withCheckedThrowingContinuation { continuation in
            // PassKit pretende il thread principale e questa funzione è
            // `async`: senza il salto esplicito potrebbe partire da una coda
            // qualsiasi e il pannello non si aprirebbe.
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: ApplePayError.sheetUnavailable)
                    return
                }

                self.continuation = continuation
                self.pendingOutcome = .cancelled

                let controller = PKPaymentAuthorizationController(paymentRequest: request)
                controller.delegate = self
                self.controller = controller

                controller.present { presented in
                    guard !presented else { return }
                    DispatchQueue.main.async {
                        self.finish(.failure(ApplePayError.sheetUnavailable))
                    }
                }
            }
        }
    }

    private func finish(_ result: Result<Outcome, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        self.controller = nil
        continuation.resume(with: result)
    }

    // MARK: - PKPaymentAuthorizationControllerDelegate

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Qui andrebbe inoltrato `payment.token` al gestore dei pagamenti, e
        // l'esito dipenderebbe dalla sua risposta. Senza un gestore dietro,
        // l'unica cosa vera da dire è: l'utente ha autorizzato.
        pendingOutcome = .authorized
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        let outcome = pendingOutcome
        controller.dismiss { [weak self] in
            DispatchQueue.main.async {
                self?.finish(.success(outcome))
            }
        }
    }
}
