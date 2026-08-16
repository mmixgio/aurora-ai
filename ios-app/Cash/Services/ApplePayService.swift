import Foundation
import PassKit

/// Il pannello di Apple Pay, quello vero — con il doppio clic del tasto
/// laterale che nel video era il gesto di conferma.
///
/// ## Perché il codice JavaScript non serviva
///
/// L'esempio con `PaymentRequest`, `onmerchantvalidation` e `validateMerchant`
/// è **Apple Pay JS**: gira dentro Safari, su un sito. In un'app nativa quelle
/// classi non esistono. L'equivalente è PassKit, ed è quello che c'è qui.
///
/// ## Cosa serve perché il pannello compaia davvero
///
/// 1. **Apple Developer Program a pagamento** (99 €/anno). Con un Apple ID
///    gratuito non si può creare un identificativo commerciante, punto.
/// 2. Un **Merchant ID** creato nel portale, tipo `merchant.com.tuonome.cash`,
///    da incollare qui sotto.
/// 3. La **capacità Apple Pay** aggiunta al target in Xcode, che genera
///    l'entitlement `com.apple.developer.in-app-payments`.
/// 4. Per incassare sul serio, un **gestore dei pagamenti** (Stripe, Adyen,
///    Nexi…) a cui mandare il token che Apple restituisce. Senza, il pannello
///    si apre e autorizza, ma nessun soldo si muove.
///
/// C'è anche un vincolo di regolamento: Apple Pay serve a pagare un esercente
/// per beni o servizi, non a mandare denaro a una persona. Un'app di
/// pagamenti fra privati non passerebbe la revisione — cosa che per un'app
/// installata solo sul proprio telefono non fa differenza, ma è giusto saperlo.
///
/// ## Come si comporta l'app
///
/// Finché `merchantIdentifier` è vuoto Apple Pay resta spento e la conferma è
/// il Face ID: funziona oggi, con un Apple ID gratuito, senza entitlement.
/// Appena metti un identificativo valido il pulsante nella schermata di
/// conferma diventa quello di Apple Pay e la sequenza passa dal suo pannello.
enum ApplePay {

    /// **L'unica riga da toccare.** Vuoto = Apple Pay spento.
    ///
    /// Attenzione: non basta scriverlo qui. Senza la capacità Apple Pay
    /// aggiunta al target il pannello non si aprirà — e la capacità richiede
    /// un profilo di provisioning a pagamento, quindi con la firma gratuita
    /// il progetto smetterebbe proprio di compilare. Vanno insieme.
    static let merchantIdentifier = ""

    /// Il paese del commerciante, non quello dell'utente.
    static let countryCode = "IT"

    static let supportedNetworks: [PKPaymentNetwork] = [
        .visa, .masterCard, .amex, .maestro, .discover
    ]

    /// `threeDSecure` è il minimo richiesto da Apple per un pagamento reale.
    static let merchantCapabilities: PKMerchantCapability = [.threeDSecure]

    static var isConfigured: Bool {
        !merchantIdentifier.isEmpty
    }

    /// Vero solo se c'è un identificativo **e** questo iPhone ha almeno una
    /// carta pronta nel Wallet. Entrambe le condizioni servono: un merchant ID
    /// su un telefono senza carte aprirebbe un pannello vuoto.
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

        // L'ultima voce dell'elenco è quella che Apple mostra in grande come
        // totale: qui ce n'è una sola, con il nome di chi riceve.
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

/// Presenta il pannello e aspetta l'esito.
///
/// PassKit parla per delegato e con blocchi di completamento; questa classe
/// li traduce in una funzione `async` sola, così la macchina a stati del
/// pagamento resta leggibile dall'alto in basso.
final class ApplePayCoordinator: NSObject, PKPaymentAuthorizationControllerDelegate {

    enum Outcome {
        /// L'utente ha confermato con il doppio clic.
        case authorized
        /// Ha chiuso il pannello senza pagare.
        case cancelled
        /// Il pannello non si è nemmeno aperto: manca l'entitlement, il
        /// merchant ID è sbagliato, o non ci sono carte nel Wallet.
        case unavailable
    }

    private var continuation: CheckedContinuation<Outcome, Never>?
    private var controller: PKPaymentAuthorizationController?

    /// L'esito viene registrato quando l'utente autorizza, ma restituito solo
    /// alla chiusura del pannello: `didAuthorizePayment` e `didFinish` sono
    /// due momenti distinti e riportare il risultato troppo presto farebbe
    /// partire l'animazione mentre il pannello di Apple è ancora a schermo.
    private var pendingOutcome: Outcome = .cancelled

    func authorize(_ request: PKPaymentRequest) async -> Outcome {
        await withCheckedContinuation { (continuation: CheckedContinuation<Outcome, Never>) in
            // PassKit pretende il thread principale, e questa funzione è
            // `async`: senza il salto esplicito potrebbe partire da una coda
            // qualsiasi e il pannello non si aprirebbe.
            DispatchQueue.main.async {
                self.continuation = continuation
                self.pendingOutcome = .cancelled

                let controller = PKPaymentAuthorizationController(paymentRequest: request)
                controller.delegate = self
                self.controller = controller

                controller.present { [weak self] presented in
                    guard !presented else { return }
                    DispatchQueue.main.async {
                        self?.finish(with: .unavailable)
                    }
                }
            }
        }
    }

    private func finish(with outcome: Outcome) {
        guard let continuation else { return }
        self.continuation = nil
        self.controller = nil
        continuation.resume(returning: outcome)
    }

    // MARK: - PKPaymentAuthorizationControllerDelegate

    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        // Qui andrebbe spedito `payment.token` al gestore dei pagamenti, e
        // l'esito dipenderebbe dalla sua risposta. Senza un gestore dietro
        // l'unica cosa onesta da dire è: l'utente ha autorizzato.
        pendingOutcome = .authorized
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        let outcome = pendingOutcome
        controller.dismiss { [weak self] in
            DispatchQueue.main.async {
                self?.finish(with: outcome)
            }
        }
    }
}
