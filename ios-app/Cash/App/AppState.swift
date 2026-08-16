import Foundation
import SwiftUI

/// Un messaggio d'errore da mostrare all'utente.
struct AppAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Lo stato condiviso: chi sei, quanto hai, cosa hai mosso.
///
/// Una sola istanza, creata all'avvio e passata alle schermate via
/// `@EnvironmentObject`. Non conosce Keychain, Contacts né LocalAuthentication:
/// parla solo con i servizi, che a loro volta parlano con i framework.
@MainActor
final class AppState: ObservableObject {

    // MARK: - Stato pubblicato

    @Published private(set) var account: BankAccount?
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var balance: Money = .zero
    @Published private(set) var signature: String = UserSignature.fallback
    @Published private(set) var hasCompletedOnboarding = false

    /// L'errore da mostrare. Nessuna vista costruisce messaggi da sé.
    @Published var alert: AppAlert?

    // MARK: - Dipendenze

    private let ledger: TransactionStore
    private let secureStore: SecureStoring
    private let persistence: LocalPersisting

    private enum SecureKey {
        static let account = "cash.bank-account"
    }

    init(
        persistence: LocalPersisting = LocalStore(),
        secureStore: SecureStoring = KeychainStore()
    ) {
        self.persistence = persistence
        self.secureStore = secureStore
        self.ledger = TransactionStore(persistence: persistence)

        loadAccount()
        refreshFromLedger()

        self.signature = persistence.loadSignature()

        // Il conto vive nel Portachiavi con `ThisDeviceOnly`, quindi dopo un
        // ripristino da backup può non esserci più anche se le preferenze
        // dicono che l'onboarding era stato fatto. Senza coordinate l'app non
        // ha nulla a cui agganciare i pagamenti: si rifà.
        self.hasCompletedOnboarding = persistence.loadOnboardingCompleted() && account != nil

        if let loadError = ledger.loadError {
            alert = AppAlert(title: "Storico non leggibile", message: loadError.message)
        }
    }

    var isReadyToPay: Bool { account != nil && hasCompletedOnboarding }

    // MARK: - Conto

    private func loadAccount() {
        do {
            account = try secureStore.load(BankAccount.self, for: SecureKey.account)
        } catch KeychainError.notFound {
            account = nil
        } catch {
            account = nil
            // Un Portachiavi illeggibile non deve impedire l'avvio, ma non va
            // nemmeno passato sotto silenzio: l'utente dovrà ricollegare.
            alert = AppAlert(
                title: "Conto non recuperato",
                message: (error as? KeychainError)?.message ?? "Ricollega il conto."
            )
        }
    }

    func link(account newAccount: BankAccount) {
        do {
            try secureStore.save(newAccount, for: SecureKey.account)
        } catch {
            alert = AppAlert(
                title: "Conto non salvato",
                message: (error as? KeychainError)?.message ?? "Riprova."
            )
            return
        }

        account = newAccount
        hasCompletedOnboarding = true
        persistence.store(onboardingCompleted: true)

        // La firma parte dall'intestatario, così la prima banconota ha già il
        // nome giusto sopra. Una firma scelta a mano non viene sovrascritta.
        if signature == UserSignature.fallback {
            updateSignature(newAccount.suggestedSignature)
        }
    }

    func unlinkAccount() {
        do {
            try secureStore.delete(SecureKey.account)
        } catch {
            alert = AppAlert(
                title: "Conto non rimosso",
                message: (error as? KeychainError)?.message ?? "Riprova."
            )
            return
        }
        account = nil
        hasCompletedOnboarding = false
        persistence.store(onboardingCompleted: false)
    }

    // MARK: - Firma

    func updateSignature(_ raw: String) {
        let normalized = UserSignature.normalize(raw)
        signature = normalized
        persistence.store(signature: normalized)
    }

    // MARK: - Movimenti

    /// Verifica un importo **prima** dell'autenticazione: non ha senso
    /// chiedere il viso per poi scoprire che il saldo non basta.
    func validate(amount: Money) -> String? {
        guard account != nil else { return "Collega prima un conto" }
        return ledger.validatePayment(amount: amount)?.message
    }

    /// Registra un pagamento già autorizzato.
    ///
    /// Chiamata **solo dopo** che l'autenticazione è riuscita e l'animazione è
    /// arrivata in fondo: è questo ordine a impedire che un pagamento
    /// interrotto a metà finisca comunque in contabilità.
    @discardableResult
    func commit(_ draft: PaymentDraft) -> Result<Transaction, TransactionStore.StoreError> {
        let transaction = draft.makeTransaction()
        do {
            try ledger.record(transaction)
            refreshFromLedger()
            return .success(transaction)
        } catch let error as TransactionStore.StoreError {
            return .failure(error)
        } catch {
            return .failure(.arithmeticOverflow)
        }
    }

    /// Denaro in entrata.
    @discardableResult
    func receive(from name: String, amount: Money) -> Result<Transaction, TransactionStore.StoreError> {
        let transaction = Transaction(
            direction: .received,
            counterpartName: name,
            amount: amount,
            serial: SerialGenerator.make()
        )

        do {
            try ledger.record(transaction)
            refreshFromLedger()
            return .success(transaction)
        } catch let error as TransactionStore.StoreError {
            return .failure(error)
        } catch {
            return .failure(.arithmeticOverflow)
        }
    }

    /// Elimina un movimento. Il saldo è derivato dallo storico, quindi
    /// togliere una riga ne annulla l'effetto.
    func deleteTransaction(id: UUID) {
        do {
            try ledger.remove(id: id)
            refreshFromLedger()
        } catch let error as TransactionStore.StoreError {
            alert = AppAlert(title: "Movimento non eliminato", message: error.message)
        } catch {
            alert = AppAlert(title: "Movimento non eliminato", message: "Riprova.")
        }
    }

    func recentCounterparts() -> [String] {
        ledger.recentCounterparts()
    }

    // MARK: - Azzeramento

    func resetEverything() {
        ledger.reset()
        try? secureStore.delete(SecureKey.account)

        account = nil
        hasCompletedOnboarding = false
        signature = UserSignature.fallback
        refreshFromLedger()
    }

    private func refreshFromLedger() {
        transactions = ledger.transactions
        balance = ledger.balance
    }
}
