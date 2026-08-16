import Foundation
import SwiftUI

/// Ciò che la macchina a stati deve poter chiedere alla contabilità.
///
/// Un protocollo e non `AppState` diretto: è il confine che permette ai test
/// di far girare l'intera sequenza con un registro finto.
@MainActor
protocol PaymentLedger: AnyObject {
    func validate(amount: Money) -> String?
    func commit(_ draft: PaymentDraft) -> Result<Transaction, TransactionStore.StoreError>
}

extension AppState: PaymentLedger {}

/// **La macchina a stati del pagamento.**
///
/// ```
/// amount  →  confirmation  →  authentication  →  sending  →  completed
///                  ↑________________|
///                        failed
/// ```
///
/// Regola non negoziabile: il movimento viene registrato **solo** dopo che
/// l'autenticazione è riuscita *e* il volo della banconota è arrivato in
/// fondo. Se qualcosa si interrompe prima, in contabilità non resta niente.
///
/// Non conosce né SwiftUI né i framework di sistema: parla con un
/// `PaymentAuthorizing`, un `PaymentLedger`, un `HardwareVolumeObserving` e
/// un `PaymentClock`, tutti sostituibili nei test.
@MainActor
final class PaymentViewModel: ObservableObject {

    // MARK: - Stato

    @Published private(set) var phase: PaymentPhase = .amount
    @Published private(set) var draft: PaymentDraft
    @Published private(set) var completed: Transaction?

    /// `false` quando i tasti del volume non sono utilizzabili: nel
    /// simulatore, o se il meccanismo non è riuscito ad attivarsi.
    @Published private(set) var hardwareVolumeAvailable = false

    /// Il motivo per cui i tasti non funzionano, quando serve dirlo.
    @Published private(set) var volumeIssue: String?

    // MARK: - Dipendenze

    private let authorizer: PaymentAuthorizing
    private weak var ledger: PaymentLedger?
    private let volume: HardwareVolumeObserving?
    private let clock: PaymentClock

    private var accelerator = StepAccelerator()

    /// Il compito che porta avanti autenticazione, volo e commit.
    ///
    /// Tenuto qui e annullato quando la schermata sparisce: è ciò che rende
    /// reale il controllo su `Task.isCancelled` prima della registrazione.
    /// Senza, un pagamento chiuso a metà volo verrebbe comunque contabilizzato.
    private var confirmationTask: Task<Void, Never>?

    init(
        recipient: ContactPerson,
        ledger: PaymentLedger,
        authorizer: PaymentAuthorizing = SystemPaymentAuthorizer(),
        volume: HardwareVolumeObserving? = nil,
        clock: PaymentClock = SystemPaymentClock()
    ) {
        self.draft = PaymentDraft(recipient: recipient)
        self.ledger = ledger
        self.authorizer = authorizer
        self.volume = volume
        self.clock = clock
    }

    // MARK: - Derivati per la vista

    var recipient: ContactPerson { draft.recipient }
    var amount: Money { draft.amount }
    var editingField: AmountField { draft.editingField }

    var authorizationMethod: AuthorizationMethod { authorizer.method }
    var isAmountValid: Bool { ledger?.validate(amount: draft.amount) == nil }

    /// Il messaggio da mostrare sotto l'importo: l'ostacolo se c'è, il saldo
    /// altrimenti. Nessuno dei due va costruito dentro la vista.
    func amountIssue() -> String? {
        guard !draft.amount.isZero else { return nil }
        return ledger?.validate(amount: draft.amount)
    }

    // MARK: - Tasti del volume

    /// Attacca il servizio hardware. Se non è disponibile lo dice invece di
    /// lasciare l'utente a premere a vuoto: i comandi a schermo restano.
    func startListeningToHardware() {
        guard let volume else {
            hardwareVolumeAvailable = false
            return
        }

        do {
            try volume.start { [weak self] direction in
                self?.step(direction == .up ? 1 : -1)
            }
            hardwareVolumeAvailable = volume.isListening
            volumeIssue = nil
        } catch let error as VolumeButtonError {
            hardwareVolumeAvailable = false
            volumeIssue = error.message
        } catch {
            hardwareVolumeAvailable = false
            volumeIssue = "Tasti del volume non disponibili"
        }
    }

    func stopListeningToHardware() {
        volume?.stop()
        hardwareVolumeAvailable = false
    }

    // MARK: - Importo

    /// Muove l'importo di un passo, `+1` o `-1`.
    func step(_ direction: Int) {
        guard phase.acceptsAmountInput, direction != 0 else { return }

        let multiplier = accelerator.multiplier(for: direction, at: Date())
        let delta = Int64(direction) * draft.editingField.stepInCents * multiplier
        let next = draft.amount.stepped(by: delta, clampedTo: AppConfiguration.amountRange)

        guard next != draft.amount else { return }

        withAnimation(Motion.value) {
            draft.amount = next
        }
        Haptics.step()
    }

    func select(field: AmountField) {
        guard draft.editingField != field else { return }
        accelerator.reset()
        withAnimation(Motion.detail) {
            draft.editingField = field
        }
    }

    /// Binding per la vista, che non deve sapere dell'acceleratore.
    var editingFieldBinding: Binding<AmountField> {
        Binding(
            get: { [weak self] in self?.draft.editingField ?? .units },
            set: { [weak self] newValue in self?.select(field: newValue) }
        )
    }

    // MARK: - Transizioni

    /// Dall'importo al riepilogo.
    func review() {
        if let issue = ledger?.validate(amount: draft.amount) {
            transition(to: .failed(issue), with: Motion.recover)
            return
        }

        Haptics.prepare()
        transition(to: .confirmation, with: Motion.phase)
    }

    /// Torna a regolare l'importo.
    func editAmount() {
        guard phase == .confirmation else { return }
        transition(to: .amount, with: Motion.phase)
    }

    /// Avvia la conferma. La vista chiama questo, non `confirm()` diretto,
    /// così il compito resta tracciato e annullabile.
    func startConfirmation() {
        guard confirmationTask == nil else { return }
        confirmationTask = Task { [weak self] in
            await self?.confirm()
            // Liberare lo slot è ciò che permette di riprovare dopo un errore;
            // tenerlo occupato bloccherebbe il pulsante per sempre.
            self?.confirmationTask = nil
        }
    }

    /// Annulla ciò che è ancora in volo. Chiamata quando la schermata esce.
    func cancelInFlight() {
        confirmationTask?.cancel()
        confirmationTask = nil
    }

    /// La conferma esplicita. Da qui in poi la sequenza va avanti da sola.
    func confirm() async {
        guard phase == .confirmation else { return }

        // Ricontrollo prima di autenticare: chiedere il viso per poi scoprire
        // che il saldo non basta sarebbe un giro a vuoto.
        if let issue = ledger?.validate(amount: draft.amount) {
            transition(to: .failed(issue), with: Motion.recover)
            return
        }

        Haptics.confirm()
        transition(to: .authentication, with: Motion.phase)

        // L'anello deve fare in tempo a comparire, o il pannello di sistema
        // lo copre sul nascere e l'animazione non si vede proprio.
        await clock.sleep(Motion.authenticationLeadIn)

        let outcome: AuthorizationOutcome
        do {
            outcome = try await authorizer.authorize(
                amount: draft.amount,
                recipientName: draft.recipient.fullName
            )
        } catch let error as BiometricError {
            Haptics.failure()
            transition(to: .failed(error.message), with: Motion.recover)
            return
        } catch {
            Haptics.failure()
            transition(to: .failed("Autenticazione non riuscita"), with: Motion.recover)
            return
        }

        guard outcome == .approved else {
            // Annullare non è un errore: si torna al riepilogo in silenzio,
            // senza schermate rosse.
            transition(to: .confirmation, with: Motion.recover)
            return
        }

        await send()
    }

    /// Il volo della banconota e, solo alla fine, il commit.
    private func send() async {
        Haptics.send()
        transition(to: .sending, with: Motion.noteFly)

        await clock.sleep(Motion.sendingFlight)

        // Se il compito è stato annullato — schermata chiusa a metà volo —
        // il pagamento non viene registrato. È il punto preciso in cui
        // l'ordine delle operazioni protegge la contabilità.
        guard !Task.isCancelled else { return }

        guard let ledger else {
            transition(to: .failed("Registro non disponibile"), with: Motion.recover)
            return
        }

        switch ledger.commit(draft) {
        case .success(let transaction):
            completed = transaction
            Haptics.success()
            transition(to: .completed, with: Motion.phase)

        case .failure(let error):
            Haptics.failure()
            transition(to: .failed(error.message), with: Motion.recover)
        }
    }

    /// Dopo un errore si torna al riepilogo, non all'importo: la cifra era
    /// giusta, è stata l'autenticazione a non passare.
    func recoverFromFailure() {
        guard case .failed = phase else { return }
        transition(to: draft.amount.isZero ? .amount : .confirmation, with: Motion.recover)
    }

    private func transition(to next: PaymentPhase, with animation: Animation) {
        withAnimation(animation) { phase = next }
    }
}
