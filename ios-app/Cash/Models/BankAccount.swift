import Foundation

/// Il conto bancario collegato all'app.
///
/// Attenzione: collegarlo qui **non muove denaro vero**. Il trasferimento
/// reale richiede un istituto di pagamento autorizzato dietro; questa app
/// registra le coordinate e simula i movimenti in locale.
struct BankAccount: Codable, Equatable {

    /// Il nome dell'intestatario, così come compare sul conto.
    var holderName: String

    /// L'IBAN in forma compatta, senza spazi e in maiuscolo.
    var iban: String

    /// Il nome della banca, dedotto dall'IBAN o scritto a mano.
    var bankName: String

    /// La data in cui il conto è stato collegato.
    var linkedAt: Date

    init(holderName: String, iban: String, bankName: String = "", linkedAt: Date = Date()) {
        self.holderName = holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iban = IBAN.compact(iban)
        self.bankName = bankName
        self.linkedAt = linkedAt
    }

    /// Le ultime quattro cifre, l'unica parte dell'IBAN che l'app mostra
    /// una volta collegato il conto.
    var lastFour: String {
        String(iban.suffix(4))
    }

    /// `IT•• •••• •••• 4471` — abbastanza per riconoscere il conto,
    /// non abbastanza per copiarlo se qualcuno guarda lo schermo.
    var maskedIBAN: String {
        guard iban.count > 6 else { return iban }
        let country = String(iban.prefix(2))
        return "\(country)•• •••• •••• \(lastFour)"
    }

    var countryCode: String {
        String(iban.prefix(2))
    }
}
