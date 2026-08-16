import Foundation

/// Dove finiscono i dati dell'app quando chiudi.
///
/// Saldo e storico stanno in `UserDefaults` (non sono segreti), le coordinate
/// bancarie nel Portachiavi. Tutto sul telefono: niente server, niente account.
enum Store {

    private enum Key {
        static let transactions = "cash.transactions"
        static let balanceCents = "cash.balance.cents"
        static let handle = "cash.profile.handle"
        static let hasOnboarded = "cash.onboarded"
        static let account = "cash.bank-account"   // → Portachiavi
    }

    private static let defaults = UserDefaults.standard

    // MARK: - Storico

    static func loadTransactions() -> [Transaction] {
        guard let data = defaults.data(forKey: Key.transactions),
              let decoded = try? JSONDecoder().decode([Transaction].self, from: data)
        else { return [] }
        return decoded
    }

    static func saveTransactions(_ transactions: [Transaction]) {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        defaults.set(data, forKey: Key.transactions)
    }

    // MARK: - Saldo

    static func loadBalance() -> Money {
        // `object(forKey:)` distingue "mai impostato" da "impostato a zero":
        // al primo avvio serve il saldo iniziale, dopo va rispettato lo zero.
        guard let stored = defaults.object(forKey: Key.balanceCents) as? Int else {
            return Money(units: 250)
        }
        return Money(cents: stored)
    }

    static func saveBalance(_ money: Money) {
        defaults.set(money.cents, forKey: Key.balanceCents)
    }

    // MARK: - Profilo

    /// La firma stampata sulla banconota. Nel video è `@BENGIANNIS`.
    static func loadHandle() -> String {
        defaults.string(forKey: Key.handle) ?? "@ME"
    }

    static func saveHandle(_ handle: String) {
        defaults.set(handle, forKey: Key.handle)
    }

    static var hasOnboarded: Bool {
        get { defaults.bool(forKey: Key.hasOnboarded) }
        set { defaults.set(newValue, forKey: Key.hasOnboarded) }
    }

    // MARK: - Conto bancario (Portachiavi)

    static func loadAccount() -> BankAccount? {
        KeychainStore.decode(BankAccount.self, for: Key.account)
    }

    static func saveAccount(_ account: BankAccount) {
        KeychainStore.encode(account, for: Key.account)
    }

    static func removeAccount() {
        KeychainStore.delete(Key.account)
    }

    /// Cancella tutto: usata dal pulsante "Azzera" nelle impostazioni.
    static func reset() {
        defaults.removeObject(forKey: Key.transactions)
        defaults.removeObject(forKey: Key.balanceCents)
        defaults.removeObject(forKey: Key.handle)
        defaults.removeObject(forKey: Key.hasOnboarded)
        removeAccount()
    }
}
