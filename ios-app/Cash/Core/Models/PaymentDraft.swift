import Foundation

/// Il pagamento mentre lo si sta componendo, prima che diventi un movimento.
///
/// È un valore puro e senza dipendenze: la macchina a stati lo trasforma, i
/// test lo costruiscono a mano, e solo al momento del commit diventa una
/// `Transaction`. Tenerli separati è ciò che impedisce a un pagamento
/// interrotto di finire nello storico.
struct PaymentDraft: Equatable, Sendable {

    let recipient: ContactPerson

    /// Il numero di serie della banconota di questo pagamento, generato una
    /// volta sola: se cambiasse a ogni ridisegno si vedrebbe ballare a schermo.
    let serial: String

    var amount: Money
    var editingField: AmountField

    init(
        recipient: ContactPerson,
        amount: Money = .zero,
        editingField: AmountField = .units,
        serial: String = SerialGenerator.make()
    ) {
        self.recipient = recipient
        self.amount = amount
        self.editingField = editingField
        self.serial = serial
    }

    /// Trasforma la bozza in un movimento registrabile.
    func makeTransaction(at date: Date = Date()) -> Transaction {
        Transaction(
            direction: .sent,
            counterpartName: recipient.fullName,
            amount: amount,
            date: date,
            serial: serial
        )
    }
}
