import Foundation

/// Il verso di un movimento.
enum PaymentDirection: String, Codable, Equatable, Sendable {
    case sent
    case received
}

/// Un movimento nello storico.
///
/// Il nome della controparte è una **copia congelata**, non un riferimento al
/// contatto: se domani quella persona sparisce dalla rubrica, lo storico deve
/// continuare a dire "Natalie" e non "Sconosciuto".
struct Transaction: Identifiable, Codable, Hashable, Sendable {

    let id: UUID
    let direction: PaymentDirection
    let counterpartName: String
    let amount: Money
    let date: Date

    /// Il numero di serie stampato sulla banconota di questo movimento.
    let serial: String

    init(
        id: UUID = UUID(),
        direction: PaymentDirection,
        counterpartName: String,
        amount: Money,
        date: Date = Date(),
        serial: String
    ) {
        self.id = id
        self.direction = direction
        self.counterpartName = counterpartName
        self.amount = amount
        self.date = date
        self.serial = serial
    }

    var initials: String {
        ContactPerson.initials(for: counterpartName)
    }

    /// L'importo con il segno, come va mostrato in lista.
    var signedAmountText: String {
        let formatted = amount.formatted()
        return direction == .sent ? "-\(formatted)" : "+\(formatted)"
    }

    /// L'effetto sul saldo: negativo in uscita, positivo in entrata.
    var balanceEffectInCents: Int64 {
        direction == .sent ? -amount.cents : amount.cents
    }
}
