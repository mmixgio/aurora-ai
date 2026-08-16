import Foundation

/// Un importo in denaro.
///
/// Tenuto in centesimi come numero intero, mai in `Double`: 0,1 + 0,2 in
/// virgola mobile non fa 0,3, e su un'app che maneggia soldi quell'errore
/// prima o poi si vede a schermo.
struct Money: Equatable, Hashable, Codable {
    /// L'importo nell'unità più piccola della valuta (centesimi).
    var cents: Int

    static let zero = Money(cents: 0)

    init(cents: Int) {
        self.cents = cents
    }

    init(units: Int, cents: Int = 0) {
        self.cents = units * 100 + cents
    }

    var isZero: Bool { cents == 0 }
    var units: Int { cents / 100 }
    var fraction: Int { abs(cents % 100) }

    /// `$20` se è un importo tondo, `$20.50` altrimenti — come nel video,
    /// dove i decimali compaiono solo quando servono davvero.
    func formatted(currency: Currency = AppConfiguration.currency) -> String {
        let sign = cents < 0 ? "-" : ""
        let value = abs(cents)
        let whole = value / 100
        let rest = value % 100

        let grouped = Money.groupDigits(whole, currency: currency)

        if rest == 0 {
            return "\(sign)\(currency.symbol)\(grouped)"
        }
        return "\(sign)\(currency.symbol)\(grouped)\(currency.decimalSeparator)\(String(format: "%02d", rest))"
    }

    /// Separatore delle migliaia, così `$1200` si legge `$1,200`.
    private static func groupDigits(_ value: Int, currency: Currency) -> String {
        let digits = Array(String(value))
        guard digits.count > 3 else { return String(digits) }

        var out: [Character] = []
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 {
                out.append(currency.groupingSeparator)
            }
            out.append(digit)
        }
        return String(out)
    }
}

/// La valuta dell'app.
///
/// Il video di riferimento usa dollari canadesi, quindi è quello che l'app
/// mostra di default. Per passare all'euro basta cambiare `AppConfiguration.currency`
/// più in basso: simbolo, codice e separatori seguono da soli.
enum Currency: String, Codable, CaseIterable {
    case cad
    case eur
    case usd

    var symbol: String {
        switch self {
        case .cad, .usd: return "$"
        case .eur: return "€"
        }
    }

    /// Il codice stampato nell'angolo in alto a destra della banconota.
    var code: String {
        switch self {
        case .cad: return "CAD"
        case .eur: return "EUR"
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

/// Le poche costanti che definiscono "che app è questa".
enum AppConfiguration {

    /// La valuta mostrata ovunque. Metti `.eur` per avere € al posto di $.
    static let currency: Currency = .cad

    /// Il tetto per singolo pagamento. Serve a evitare che uno zero di troppo
    /// digitato per sbaglio diventi un pagamento da cinquantamila.
    static let maximumPayment = Money(units: 5_000)

    /// Quante cifre può digitare al massimo il tastierino.
    static let maximumDigits = 7
}
