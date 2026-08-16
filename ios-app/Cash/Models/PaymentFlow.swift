import Foundation
import SwiftUI

/// La macchina a stati del pagamento.
///
/// ```
/// importo  →  conferma  →  Face ID  →  invio  →  fatto
///                 ↑____________|
///              (annullato o viso non riconosciuto)
/// ```
///
/// L'importo si regola con i tasti del volume, la conferma è un pulsante, e
/// solo dopo il pulsante compare il Face ID: l'autenticazione è l'ultimo
/// passaggio prima che il denaro parta, non un dazio da pagare all'ingresso.
@MainActor
final class PaymentFlow: ObservableObject {

    enum Phase: Equatable {
        /// Si sceglie quanto mandare.
        case composing
        /// Riepilogo con il pulsante "Conferma pagamento".
        case confirming
        /// Anello verde, Face ID di sistema aperto.
        case authenticating
        /// La banconota vola verso l'avatar del destinatario.
        case sending
        /// ✓ "Inviato a Natalie".
        case sent
        /// Qualcosa è andato storto: il messaggio è quello da mostrare.
        case failed(String)
    }

    @Published private(set) var phase: Phase = .composing
    @Published private(set) var amount: Money = .zero
    @Published private(set) var recipient: Contact

    /// Su quale parte dell'importo agiscono i tasti del volume.
    @Published var editingField: AmountField = .units

    /// Riempita a pagamento concluso, per la schermata finale.
    @Published private(set) var completed: Transaction?

    /// Il numero di serie della banconota, generato una volta sola: se
    /// cambiasse a ogni ridisegno si vedrebbe ballare sotto gli occhi.
    let serial: String = Transaction.makeSerial()

    private unowned let appState: AppState

    /// Chi chiede la conferma all'utente.
    enum ConfirmationMethod {
        /// Il pannello di Apple Pay, con il doppio clic del tasto laterale.
        /// Richiede un Merchant ID configurato in `ApplePay`.
        case applePay
        /// Il Face ID di sistema. È la strada che funziona con un Apple ID
        /// gratuito, senza entitlement e senza gestore dei pagamenti.
        case biometrics
    }

    var confirmationMethod: ConfirmationMethod {
        ApplePay.isAvailable ? .applePay : .biometrics
    }

    private let applePay = ApplePayCoordinator()

    init(recipient: Contact, appState: AppState) {
        self.recipient = recipient
        self.appState = appState
    }

    // MARK: - Regolazione dell'importo

    /// Quando è avvenuta l'ultima variazione e in che verso: servono a
    /// riconoscere una raffica di pressioni da una pressione isolata.
    private var lastStepAt: Date?
    private var lastDirection: Int = 0
    private var streak: Int = 0

    /// Muove l'importo di un passo, `+1` o `-1`.
    ///
    /// Tenendo premuto il tasto del volume le pressioni si susseguono in
    /// fretta: da un certo punto in poi il passo cresce, altrimenti arrivare
    /// a 200 € vorrebbe dire premere duecento volte. Rallentando, o cambiando
    /// verso, si torna subito al passo da uno per aggiustare con precisione.
    func step(_ direction: Int) {
        guard phase == .composing, direction != 0 else { return }

        let now = Date()
        let isBurst = lastStepAt.map { now.timeIntervalSince($0) < 0.45 } ?? false
        streak = (isBurst && direction == lastDirection) ? streak + 1 : 0

        lastStepAt = now
        lastDirection = direction

        let delta = direction * editingField.stepInCents * multiplier(for: streak)
        let target = min(max(amount.cents + delta, 0), AppConfiguration.maximumPayment.cents)

        guard target != amount.cents else { return }

        withAnimation(Motion.value) {
            amount = Money(cents: target)
        }
        Haptics.tap()
    }

    private func multiplier(for streak: Int) -> Int {
        switch streak {
        case 0...2:  return 1
        case 3...6:  return 2
        case 7...12: return 5
        default:     return AppConfiguration.maximumStepMultiplier
        }
    }

    /// Azzera l'accelerazione. Da chiamare quando si passa da euro a
    /// centesimi, altrimenti il primo tocco sui centesimi erediterebbe la
    /// velocità accumulata sugli euro.
    func resetStepAcceleration() {
        streak = 0
        lastStepAt = nil
        lastDirection = 0
    }

    // MARK: - Transizioni

    /// Dall'importo al riepilogo.
    func review() {
        if let issue = appState.validate(amount: amount) {
            fail(issue.localizedDescription)
            return
        }

        Haptics.prepare()
        withAnimation(Motion.phase) {
            phase = .confirming
        }
    }

    /// Torna alla regolazione dell'importo.
    func edit() {
        guard phase == .confirming else { return }
        withAnimation(Motion.phase) {
            phase = .composing
        }
    }

    /// La conferma del pagamento. Da qui in poi la sequenza va avanti da sola.
    func confirm() async {
        guard phase == .confirming else { return }

        if let issue = appState.validate(amount: amount) {
            fail(issue.localizedDescription)
            return
        }

        Haptics.arm()
        withAnimation(Motion.phase) {
            phase = .authenticating
        }

        let approved: Bool
        switch confirmationMethod {
        case .applePay:
            approved = await confirmWithApplePay()
        case .biometrics:
            approved = await confirmWithBiometrics()
        }

        guard approved else { return }
        await send()
    }

    /// Apre il pannello di Apple Pay.
    ///
    /// Se il pannello non riesce ad aprirsi — entitlement mancante, merchant
    /// ID sbagliato, nessuna carta nel Wallet — si ripiega sul Face ID invece
    /// di lasciare il pagamento appeso senza spiegazioni.
    private func confirmWithApplePay() async -> Bool {
        let request = ApplePay.request(
            amount: amount,
            recipientName: recipient.fullName
        )

        switch await applePay.authorize(request) {
        case .authorized:
            return true

        case .cancelled:
            // Chiudere il pannello di Apple Pay non è un errore: si torna al
            // riepilogo in silenzio, senza schermate rosse.
            withAnimation(Motion.recover) { phase = .confirming }
            return false

        case .unavailable:
            return await confirmWithBiometrics()
        }
    }

    private func confirmWithBiometrics() async -> Bool {
        // Un istante prima di aprire il Face ID: l'anello verde deve fare in
        // tempo a comparire, altrimenti il pannello di sistema lo copre sul
        // nascere e l'animazione non si vede proprio.
        try? await Task.sleep(nanoseconds: 260_000_000)

        do {
            try await BiometricService.authenticate(
                reason: "Conferma il pagamento di \(amount.formatted()) a \(recipient.displayName)"
            )
            return true
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Autenticazione non riuscita"
            fail(message)
            return false
        }
    }

    private func send() async {
        Haptics.send()
        withAnimation(Motion.noteFly) {
            phase = .sending
        }

        // Il tempo che la banconota impiega ad arrivare nell'avatar: è
        // l'animazione a dettare la durata, non il contrario.
        try? await Task.sleep(nanoseconds: 950_000_000)

        completed = appState.commitPayment(
            to: recipient,
            amount: amount,
            serial: serial
        )
        Haptics.success()

        withAnimation(Motion.phase) {
            phase = .sent
        }
    }

    private func fail(_ message: String) {
        Haptics.failure()
        withAnimation(Motion.recover) {
            phase = .failed(message)
        }
    }

    /// Dopo un errore si torna al riepilogo, non all'importo: la cifra era
    /// giusta, è stata l'autenticazione a non passare.
    func recoverFromFailure() {
        guard case .failed = phase else { return }
        withAnimation(Motion.recover) {
            phase = amount.isZero ? .composing : .confirming
        }
    }

    // MARK: - Comodità per le viste

    var amountText: String { amount.formatted() }

    var isAmountValid: Bool { appState.validate(amount: amount) == nil }

    /// I tasti del volume vanno ascoltati solo mentre si regola l'importo.
    var acceptsVolumeInput: Bool { phase == .composing }
}
