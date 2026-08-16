import Foundation

/// Il libro mastro dell'app.
///
/// ## Il saldo è derivato, non memorizzato
///
/// Viene salvato solo il **saldo di partenza**; quello corrente è sempre
/// `partenza + somma degli effetti dei movimenti`. Tenere due verità separate
/// — un saldo scritto su disco e uno storico scritto accanto — significa
/// prima o poi vederle divergere dopo un salvataggio interrotto a metà.
/// Così esiste una sola fonte, e cancellare un movimento riporta il saldo
/// esattamente a com'era: la coerenza è garantita dalla struttura, non dalla
/// disciplina di chi scrive il codice.
///
/// Non è isolato su un attore: è logica pura, e i test la esercitano
/// direttamente senza dover passare dal main thread.
final class TransactionStore {

    enum StoreError: Error, Equatable {
        case duplicateTransaction(UUID)
        case insufficientFunds(available: Money, requested: Money)
        case amountNotPositive
        case aboveLimit(maximum: Money)
        case arithmeticOverflow
        case persistence(PersistenceError)

        var message: String {
            switch self {
            case .duplicateTransaction:
                return "Questo movimento è già stato registrato"
            case .insufficientFunds(let available, _):
                return "Saldo non sufficiente: hai \(available.formatted())"
            case .amountNotPositive:
                return "Inserisci un importo"
            case .aboveLimit(let maximum):
                return "Il massimo per pagamento è \(maximum.formatted())"
            case .arithmeticOverflow:
                return "Importo fuori scala"
            case .persistence(let error):
                return error.message
            }
        }
    }

    private(set) var transactions: [Transaction]
    private(set) var openingBalance: Money

    /// Ricalcolato a ogni modifica invece che a ogni lettura: la somma è
    /// lineare sui movimenti e il saldo viene letto molte più volte di quanto
    /// cambi.
    private(set) var balance: Money

    /// Valorizzato se all'avvio lo storico su disco non era leggibile.
    /// L'app parte comunque, ma può dirlo invece di fingere che sia vuoto.
    private(set) var loadError: PersistenceError?

    private let persistence: LocalPersisting

    init(persistence: LocalPersisting) {
        self.persistence = persistence
        self.openingBalance = persistence.loadOpeningBalance()

        do {
            self.transactions = try persistence.loadTransactions()
            self.loadError = nil
        } catch let error as PersistenceError {
            // Uno storico illeggibile non deve impedire l'avvio: si riparte
            // vuoti e si conserva il motivo per poterlo mostrare.
            self.transactions = []
            self.loadError = error
        } catch {
            self.transactions = []
            self.loadError = .decodingFailed("lo storico")
        }

        self.balance = TransactionStore.computeBalance(
            opening: openingBalance,
            transactions: transactions
        )
    }

    // MARK: - Interrogazione

    /// Le ultime persone con cui c'è stato uno scambio, senza ripetizioni.
    /// Alimenta la sezione "Recenti" e non richiede una lista a parte.
    func recentCounterparts(limit: Int = AppConfiguration.recentRecipientsLimit) -> [String] {
        var seen = Set<String>()
        var names: [String] = []

        for transaction in transactions where seen.insert(transaction.counterpartName).inserted {
            names.append(transaction.counterpartName)
            if names.count == limit { break }
        }
        return names
    }

    /// Verifica un pagamento **prima** di autenticare l'utente: non ha senso
    /// chiedere il viso per poi scoprire che il saldo non basta.
    func validatePayment(amount: Money) -> StoreError? {
        guard amount.cents > 0 else { return .amountNotPositive }
        guard amount <= AppConfiguration.maximumPayment else {
            return .aboveLimit(maximum: AppConfiguration.maximumPayment)
        }
        guard amount <= balance else {
            return .insufficientFunds(available: balance, requested: amount)
        }
        return nil
    }

    // MARK: - Modifica

    /// Registra un movimento.
    ///
    /// Il controllo di duplicazione è sull'identificatore: un tocco doppio, o
    /// una schermata riaperta due volte, non deve poter addebitare due volte
    /// lo stesso pagamento.
    @discardableResult
    func record(_ transaction: Transaction) throws -> Money {
        guard !transactions.contains(where: { $0.id == transaction.id }) else {
            throw StoreError.duplicateTransaction(transaction.id)
        }

        if transaction.direction == .sent, let issue = validatePayment(amount: transaction.amount) {
            throw issue
        }

        var next = transactions
        next.insert(transaction, at: 0)

        let newBalance = try TransactionStore.safeBalance(
            opening: openingBalance,
            transactions: next
        )

        transactions = next
        balance = newBalance
        try persist()
        return balance
    }

    /// Elimina un movimento e **riporta il saldo a com'era**.
    ///
    /// Conseguenza diretta del saldo derivato: togliere una riga dal registro
    /// ne annulla l'effetto. È anche il comportamento che un utente si
    /// aspetta, visto che il gesto è "elimina" e non "archivia".
    func remove(id: UUID) throws {
        guard let index = transactions.firstIndex(where: { $0.id == id }) else { return }

        var next = transactions
        next.remove(at: index)

        let newBalance = try TransactionStore.safeBalance(
            opening: openingBalance,
            transactions: next
        )

        transactions = next
        balance = newBalance
        try persist()
    }

    func reset() {
        persistence.reset()
        transactions = []
        openingBalance = persistence.loadOpeningBalance()
        balance = openingBalance
        loadError = nil
    }

    // MARK: - Calcolo

    static func computeBalance(opening: Money, transactions: [Transaction]) -> Money {
        let total = transactions.reduce(opening.cents) { partial, transaction in
            partial &+ transaction.balanceEffectInCents
        }
        return Money(cents: total)
    }

    /// Come sopra, ma segnala l'overflow invece di avvolgersi in silenzio.
    private static func safeBalance(opening: Money, transactions: [Transaction]) throws -> Money {
        var total = opening.cents
        for transaction in transactions {
            let (sum, didOverflow) = total.addingReportingOverflow(transaction.balanceEffectInCents)
            guard !didOverflow else { throw StoreError.arithmeticOverflow }
            total = sum
        }
        return Money(cents: total)
    }

    private func persist() throws {
        do {
            try persistence.store(transactions: transactions)
        } catch let error as PersistenceError {
            throw StoreError.persistence(error)
        }
    }
}
