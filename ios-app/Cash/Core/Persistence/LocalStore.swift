import Foundation

/// Cosa può andare storto leggendo o scrivendo i dati locali.
enum PersistenceError: Error, Equatable {
    case encodingFailed(String)
    case decodingFailed(String)

    var message: String {
        switch self {
        case .encodingFailed(let what):
            return "Non è stato possibile salvare \(what)"
        case .decodingFailed(let what):
            return "I dati salvati di \(what) non sono leggibili"
        }
    }
}

/// L'archivio dei dati non sensibili.
///
/// Dietro un protocollo perché i test devono poter girare su una versione in
/// memoria: appoggiarsi a `UserDefaults.standard` renderebbe ogni test
/// dipendente dall'ordine di esecuzione e dallo stato lasciato dal precedente.
protocol LocalPersisting: AnyObject {
    func loadTransactions() throws -> [Transaction]
    func store(transactions: [Transaction]) throws

    /// Il saldo di partenza. Il saldo corrente **non** viene salvato: si
    /// ricava da qui più la somma dei movimenti (vedi `TransactionStore`).
    func loadOpeningBalance() -> Money
    func store(openingBalance: Money)

    func loadSignature() -> String
    func store(signature: String)

    func loadOnboardingCompleted() -> Bool
    func store(onboardingCompleted: Bool)

    func reset()
}

/// L'implementazione su `UserDefaults`.
///
/// Qui finiscono solo dati non sensibili: saldo, storico, firma, stato
/// dell'onboarding. IBAN e intestatario stanno nel Portachiavi, mai qui.
final class LocalStore: LocalPersisting {

    private enum Key {
        static let transactions = "cash.transactions"
        static let openingBalance = "cash.balance.opening.cents"
        static let signature = "cash.profile.signature"
        static let onboarding = "cash.onboarding.completed"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - Storico

    func loadTransactions() throws -> [Transaction] {
        guard let data = defaults.data(forKey: Key.transactions) else { return [] }
        do {
            return try JSONDecoder().decode([Transaction].self, from: data)
        } catch {
            throw PersistenceError.decodingFailed("lo storico")
        }
    }

    func store(transactions: [Transaction]) throws {
        do {
            let data = try JSONEncoder().encode(transactions)
            defaults.set(data, forKey: Key.transactions)
        } catch {
            throw PersistenceError.encodingFailed("lo storico")
        }
    }

    // MARK: - Saldo di partenza

    func loadOpeningBalance() -> Money {
        // `object(forKey:)` distingue "mai impostato" da "impostato a zero":
        // al primo avvio serve il saldo iniziale, dopo va rispettato lo zero.
        guard let stored = defaults.object(forKey: Key.openingBalance) as? NSNumber else {
            return AppConfiguration.initialBalance
        }
        return Money(cents: stored.int64Value)
    }

    func store(openingBalance: Money) {
        defaults.set(NSNumber(value: openingBalance.cents), forKey: Key.openingBalance)
    }

    // MARK: - Profilo

    func loadSignature() -> String {
        defaults.string(forKey: Key.signature) ?? UserSignature.fallback
    }

    func store(signature: String) {
        defaults.set(signature, forKey: Key.signature)
    }

    func loadOnboardingCompleted() -> Bool {
        defaults.bool(forKey: Key.onboarding)
    }

    func store(onboardingCompleted: Bool) {
        defaults.set(onboardingCompleted, forKey: Key.onboarding)
    }

    func reset() {
        [Key.transactions, Key.openingBalance, Key.signature, Key.onboarding]
            .forEach(defaults.removeObject(forKey:))
    }
}
