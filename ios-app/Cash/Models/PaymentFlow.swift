import Foundation
import SwiftUI

/// La macchina a stati del pagamento, cioè la sequenza del video.
///
/// ```
/// importo  →  armato  →  Face ID  →  invio  →  fatto
///                ↑___________|
///             (annullato o non riconosciuto)
/// ```
@MainActor
final class PaymentFlow: ObservableObject {

    enum Phase: Equatable {
        /// Tastierino: stai digitando quanto mandare.
        case composing
        /// `$20` a schermo e la scritta lampeggiante: l'app aspetta il gesto.
        case armed
        /// Anello verde in alto, Face ID di sistema aperto.
        case authenticating
        /// La banconota vola verso l'avatar del destinatario.
        case sending
        /// ✓ "Sent to Natalie".
        case sent
        /// Qualcosa è andato storto: il messaggio è quello da mostrare.
        case failed(String)
    }

    @Published private(set) var phase: Phase = .composing
    @Published var amount: Money = .zero
    @Published private(set) var recipient: Contact

    /// Il numero di serie della banconota di questo pagamento: generato una
    /// volta sola all'inizio, così il numero non cambia sotto gli occhi
    /// mentre la banconota è a schermo.
    let serial: String = Transaction.makeSerial()

    /// Riempita a pagamento concluso, per poterla mostrare nella schermata finale.
    @Published private(set) var completed: Transaction?

    private unowned let appState: AppState

    init(recipient: Contact, appState: AppState) {
        self.recipient = recipient
        self.appState = appState
    }

    // MARK: - Tastierino

    /// Le cifre digitate finora, in centesimi. `2000` = `$20.00`.
    @Published private(set) var typedDigits: String = ""

    func type(_ digit: Int) {
        guard typedDigits.count < AppConfiguration.maximumDigits else { return }
        // Evita che l'importo inizi con degli zeri inutili.
        if typedDigits.isEmpty && digit == 0 { return }

        typedDigits.append(String(digit))
        syncAmountFromDigits()
        Haptics.tap()
    }

    func deleteDigit() {
        guard !typedDigits.isEmpty else { return }
        typedDigits.removeLast()
        syncAmountFromDigits()
        Haptics.tap()
    }

    private func syncAmountFromDigits() {
        amount = Money(cents: Int(typedDigits) ?? 0)
    }

    // MARK: - Transizioni

    /// Dal tastierino alla schermata del gesto.
    func arm() {
        if let issue = appState.validate(amount: amount) {
            fail(issue.localizedDescription)
            return
        }

        Haptics.prepare()
        withAnimation(.smooth(duration: 0.45)) {
            phase = .armed
        }
    }

    /// Torna al tastierino, per correggere l'importo.
    func disarm() {
        guard phase == .armed else { return }
        withAnimation(.smooth(duration: 0.35)) {
            phase = .composing
        }
    }

    /// Il gesto di pagamento. Da qui in poi la sequenza va avanti da sola.
    func confirm() async {
        guard phase == .armed else { return }

        if let issue = appState.validate(amount: amount) {
            fail(issue.localizedDescription)
            return
        }

        Haptics.arm()
        withAnimation(.smooth(duration: 0.4)) {
            phase = .authenticating
        }

        do {
            try await BiometricService.authenticate(
                reason: "Conferma il pagamento di \(amount.formatted()) a \(recipient.displayName)"
            )
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? "Autenticazione non riuscita"
            fail(message)
            return
        }

        await send()
    }

    private func send() async {
        Haptics.send()
        withAnimation(.smooth(duration: 0.55)) {
            phase = .sending
        }

        // Il tempo che la banconota impiega ad arrivare nell'avatar.
        // È l'animazione a dettare la durata, non il contrario.
        try? await Task.sleep(nanoseconds: 900_000_000)

        let transaction = appState.commitPayment(
            to: recipient,
            amount: amount,
            serial: serial
        )

        completed = transaction
        Haptics.success()

        withAnimation(.smooth(duration: 0.45)) {
            phase = .sent
        }
    }

    private func fail(_ message: String) {
        Haptics.failure()
        withAnimation(.smooth(duration: 0.3)) {
            phase = .failed(message)
        }
    }

    /// Dopo un errore si torna alla schermata del gesto, non al tastierino:
    /// l'importo era giusto, è stata l'autenticazione a non passare.
    func recoverFromFailure() {
        guard case .failed = phase else { return }
        withAnimation(.smooth(duration: 0.35)) {
            phase = amount.isZero ? .composing : .armed
        }
    }

    // MARK: - Testi

    /// L'importo così come va scritto a schermo: `$0` finché non digiti nulla.
    var amountText: String {
        amount.formatted()
    }

    var isAmountValid: Bool {
        appState.validate(amount: amount) == nil
    }
}
