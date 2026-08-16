import Foundation
import SwiftUI

/// Lo stato condiviso dell'app: chi sei, quanto hai, cosa hai mandato.
///
/// Una sola istanza, creata all'avvio e passata a tutte le schermate
/// tramite `@EnvironmentObject`.
@MainActor
final class AppState: ObservableObject {

    /// Il conto collegato. Finché è `nil` l'app non lascia pagare.
    @Published private(set) var account: BankAccount?

    @Published private(set) var balance: Money
    @Published private(set) var transactions: [Transaction]

    /// La firma stampata sulla banconota (`@BENGIANNIS` nel video).
    @Published var handle: String {
        didSet { Store.saveHandle(handle) }
    }

    /// Diventa `true` quando il conto è collegato la prima volta.
    @Published var hasOnboarded: Bool {
        didSet { Store.hasOnboarded = hasOnboarded }
    }

    init() {
        let savedAccount = Store.loadAccount()
        self.account = savedAccount
        self.balance = Store.loadBalance()
        self.transactions = Store.loadTransactions()
        self.handle = Store.loadHandle()

        // Se il conto è sparito dal Portachiavi (capita ripristinando il
        // telefono da un backup), l'onboarding va rifatto: senza coordinate
        // l'app non ha niente a cui agganciare i pagamenti.
        self.hasOnboarded = Store.hasOnboarded && savedAccount != nil
    }

    var isReadyToPay: Bool {
        account != nil && hasOnboarded
    }

    // MARK: - Conto

    func link(account: BankAccount) {
        self.account = account
        Store.saveAccount(account)
        hasOnboarded = true
    }

    func unlinkAccount() {
        account = nil
        hasOnboarded = false
        Store.removeAccount()
    }

    // MARK: - Pagamenti

    /// Cosa può impedire a un pagamento di partire, prima ancora del Face ID.
    enum PaymentIssue: LocalizedError {
        case noAccount
        case zeroAmount
        case overLimit(Money)
        case insufficientFunds

        var errorDescription: String? {
            switch self {
            case .noAccount:
                return "Collega prima un conto"
            case .zeroAmount:
                return "Inserisci un importo"
            case .overLimit(let maximum):
                return "Il massimo per pagamento è \(maximum.formatted())"
            case .insufficientFunds:
                return "Saldo non sufficiente"
            }
        }
    }

    func validate(amount: Money) -> PaymentIssue? {
        guard account != nil else { return .noAccount }
        guard amount.cents > 0 else { return .zeroAmount }
        guard amount.cents <= AppConfiguration.maximumPayment.cents else {
            return .overLimit(AppConfiguration.maximumPayment)
        }
        guard amount.cents <= balance.cents else { return .insufficientFunds }
        return nil
    }

    /// Registra il pagamento e aggiorna il saldo.
    ///
    /// Da chiamare **solo dopo** che il Face ID è andato a buon fine.
    @discardableResult
    func commitPayment(to contact: Contact, amount: Money, serial: String) -> Transaction {
        let transaction = Transaction(
            direction: .sent,
            counterpartName: contact.fullName,
            amount: amount,
            serial: serial
        )

        transactions.insert(transaction, at: 0)
        balance = Money(cents: balance.cents - amount.cents)

        persist()
        return transaction
    }

    /// Denaro in entrata. Per ora serve solo alla schermata "Richiedi",
    /// ma il movimento nello storico è identico a quello in uscita.
    @discardableResult
    func receive(from name: String, amount: Money) -> Transaction {
        let transaction = Transaction(
            direction: .received,
            counterpartName: name,
            amount: amount
        )

        transactions.insert(transaction, at: 0)
        balance = Money(cents: balance.cents + amount.cents)

        persist()
        return transaction
    }

    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
        Store.saveTransactions(transactions)
    }

    /// Le persone a cui hai mandato denaro più di recente, senza ripetizioni.
    /// Alimenta la riga di avatar in cima alla home.
    func recentCounterparts(limit: Int = 8) -> [String] {
        var seen = Set<String>()
        var names: [String] = []

        for transaction in transactions {
            if seen.insert(transaction.counterpartName).inserted {
                names.append(transaction.counterpartName)
            }
            if names.count == limit { break }
        }
        return names
    }

    private func persist() {
        Store.saveTransactions(transactions)
        Store.saveBalance(balance)
    }

    // MARK: - Azzeramento

    func resetEverything() {
        Store.reset()
        account = nil
        balance = Store.loadBalance()
        transactions = []
        handle = Store.loadHandle()
        hasOnboarded = false
    }
}
