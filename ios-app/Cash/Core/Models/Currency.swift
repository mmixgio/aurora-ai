import Foundation

/// La valuta dell'app.
enum Currency: String, Codable, CaseIterable, Sendable {
    case eur
    case cad
    case usd

    var symbol: String {
        switch self {
        case .eur: return "€"
        case .cad, .usd: return "$"
        }
    }

    /// Il codice ISO 4217, stampato sulla banconota e richiesto da PassKit.
    var code: String {
        switch self {
        case .eur: return "EUR"
        case .cad: return "CAD"
        case .usd: return "USD"
        }
    }

    var decimalSeparator: String {
        switch self {
        case .eur: return ","
        case .cad, .usd: return "."
        }
    }

    var groupingSeparator: Character {
        switch self {
        case .eur: return "."
        case .cad, .usd: return ","
        }
    }
}

/// Le costanti che definiscono il comportamento dell'app.
///
/// Ogni numero che conta per l'esperienza sta qui e non sparso nelle viste:
/// se domani il tetto passa a 10.000 € si cambia una riga, non dodici.
enum AppConfiguration {

    /// La valuta mostrata ovunque. `.cad` riporta al dollaro del video.
    static let currency: Currency = .eur

    /// Saldo al primo avvio.
    static let initialBalance = Money(units: 250)

    /// Tetto per singolo pagamento: evita che uno zero digitato per sbaglio
    /// diventi un pagamento da cinquantamila.
    static let maximumPayment = Money(units: 5_000)

    /// L'intervallo in cui l'importo può muoversi.
    static let amountRange: ClosedRange<Money> = Money.zero...maximumPayment

    /// Il moltiplicatore massimo raggiungibile tenendo premuto il volume.
    static let maximumStepMultiplier: Int64 = 10

    /// Oltre questo intervallo fra due pressioni l'accelerazione si azzera.
    static let stepBurstWindow: TimeInterval = 0.45

    /// Quanti destinatari recenti mostrare in cima alla lista contatti.
    static let recentRecipientsLimit = 8
}
