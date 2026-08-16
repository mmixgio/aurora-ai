import Foundation

/// Un importo di denaro.
///
/// Conservato in centesimi come `Int64`, mai in virgola mobile: in `Double`
/// 0,1 + 0,2 non fa 0,3, e su una contabilità quell'errore prima o poi
/// affiora a schermo. `Int64` copre ±92 milioni di miliardi di centesimi,
/// abbondantemente oltre qualsiasi importo che questa app possa vedere.
///
/// Il tipo è immutabile: ogni operazione restituisce un nuovo `Money`, così
/// non esiste un punto del programma in cui un importo cambia sotto i piedi
/// di chi lo sta leggendo.
struct Money: Equatable, Hashable, Codable, Comparable, Sendable {

    /// L'importo nell'unità minima della valuta.
    let cents: Int64

    static let zero = Money(cents: 0)

    init(cents: Int64) {
        self.cents = cents
    }

    /// `Money(units: 250)` → 250,00 €.
    init(units: Int64, cents: Int64 = 0) {
        self.cents = units * 100 + cents
    }

    // MARK: - Interrogazione

    var isZero: Bool { cents == 0 }
    var isNegative: Bool { cents < 0 }
    var units: Int64 { cents / 100 }
    var fraction: Int64 { abs(cents % 100) }

    static func < (lhs: Money, rhs: Money) -> Bool { lhs.cents < rhs.cents }

    // MARK: - Aritmetica

    /// Errori che l'aritmetica monetaria può produrre.
    ///
    /// L'overflow su `Int64` è irraggiungibile con importi reali, ma un tipo
    /// che rappresenta denaro non deve avere comportamenti indefiniti nemmeno
    /// nei casi che "non capitano mai".
    enum ArithmeticError: Error, Equatable {
        case overflow
    }

    func adding(_ other: Money) throws -> Money {
        let (result, didOverflow) = cents.addingReportingOverflow(other.cents)
        guard !didOverflow else { throw ArithmeticError.overflow }
        return Money(cents: result)
    }

    func subtracting(_ other: Money) throws -> Money {
        let (result, didOverflow) = cents.subtractingReportingOverflow(other.cents)
        guard !didOverflow else { throw ArithmeticError.overflow }
        return Money(cents: result)
    }

    /// Somma o sottrae un numero di centesimi restando dentro un intervallo.
    ///
    /// È l'operazione dei tasti del volume: non deve mai poter uscire dai
    /// limiti, quindi satura invece di fallire.
    func stepped(by deltaInCents: Int64, clampedTo range: ClosedRange<Money>) -> Money {
        let (raw, didOverflow) = cents.addingReportingOverflow(deltaInCents)
        let candidate = didOverflow ? (deltaInCents > 0 ? Int64.max : Int64.min) : raw
        return Money(cents: min(max(candidate, range.lowerBound.cents), range.upperBound.cents))
    }

    // MARK: - Rappresentazione

    /// L'importo nel tipo che PassKit richiede.
    ///
    /// Costruito dai centesimi con esponente -2, senza passare da `Double`:
    /// convertire in virgola mobile e tornare indietro è esattamente il modo
    /// in cui 20,00 diventa 19,999999.
    var decimalNumber: NSDecimalNumber {
        NSDecimalNumber(
            mantissa: UInt64(cents.magnitude),
            exponent: -2,
            isNegative: cents < 0
        )
    }

    /// La parte intera come testo, senza segno.
    func unitsText(currency: Currency = AppConfiguration.currency) -> String {
        Money.group(abs(units), separator: currency.groupingSeparator)
    }

    /// I centesimi come testo a due cifre.
    var fractionText: String {
        String(format: "%02d", fraction)
    }

    /// `€20` se l'importo è tondo, `€20,50` altrimenti: i decimali compaiono
    /// solo quando aggiungono informazione.
    func formatted(currency: Currency = AppConfiguration.currency) -> String {
        let sign = cents < 0 ? "-" : ""
        let whole = unitsText(currency: currency)

        guard fraction != 0 else {
            return "\(sign)\(currency.symbol)\(whole)"
        }
        return "\(sign)\(currency.symbol)\(whole)\(currency.decimalSeparator)\(fractionText)"
    }

    /// Forma sempre estesa, con i centesimi anche quando sono zero.
    func formattedExact(currency: Currency = AppConfiguration.currency) -> String {
        let sign = cents < 0 ? "-" : ""
        return "\(sign)\(currency.symbol)\(unitsText(currency: currency))"
            + "\(currency.decimalSeparator)\(fractionText)"
    }

    /// Separatore delle migliaia: `1200` → `1.200`.
    private static func group(_ value: Int64, separator: Character) -> String {
        let digits = Array(String(value))
        guard digits.count > 3 else { return String(digits) }

        var out: [Character] = []
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 {
                out.append(separator)
            }
            out.append(digit)
        }
        return String(out)
    }
}
