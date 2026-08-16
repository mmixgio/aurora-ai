import Foundation

/// Il conto collegato all'app.
///
/// Registrarlo qui **non muove denaro**: la contabilità è locale e non esiste
/// alcun collegamento a un circuito bancario. L'IBAN vive solo nel Portachiavi.
struct BankAccount: Codable, Equatable, Sendable {

    let holderName: String

    /// L'IBAN in forma compatta, senza spazi e in maiuscolo.
    let iban: String

    let linkedAt: Date

    init(holderName: String, iban: String, linkedAt: Date = Date()) {
        self.holderName = holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.iban = IBANValidator.compact(iban)
        self.linkedAt = linkedAt
    }

    var countryCode: String { String(iban.prefix(2)) }

    /// Le ultime quattro cifre, l'unica parte che l'app rimostra.
    var lastFour: String { String(iban.suffix(4)) }

    /// `IT•• •••• •••• 4471`: abbastanza per riconoscere il conto, non
    /// abbastanza perché qualcuno lo copi guardando lo schermo.
    var maskedIBAN: String {
        guard iban.count > 6 else { return iban }
        return "\(countryCode)•• •••• •••• \(lastFour)"
    }

    /// La firma proposta per la banconota, derivata dall'intestatario.
    /// "Giovanni Maffei" → "@GIOVANNI".
    var suggestedSignature: String {
        guard let first = holderName.split(separator: " ").first else { return "@ME" }
        return UserSignature.normalize(String(first))
    }
}
