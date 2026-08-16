import Foundation

/// Validazione e formattazione degli IBAN.
///
/// Il controllo è quello vero previsto dallo standard ISO 13616: lunghezza
/// per paese e cifra di controllo modulo 97. Non garantisce che il conto
/// esista, ma scarta subito un IBAN scritto male o inventato.
enum IBAN {

    /// Lunghezza esatta dell'IBAN per i paesi SEPA più comuni.
    /// Un paese non elencato passa comunque, purché la cifra di controllo torni.
    static let lengthsByCountry: [String: Int] = [
        "AD": 24, "AT": 20, "BE": 16, "BG": 22, "CH": 21, "CY": 28, "CZ": 24,
        "DE": 22, "DK": 18, "EE": 20, "ES": 24, "FI": 18, "FR": 27, "GB": 22,
        "GI": 23, "GR": 27, "HR": 21, "HU": 28, "IE": 22, "IS": 26, "IT": 27,
        "LI": 21, "LT": 20, "LU": 20, "LV": 21, "MC": 27, "MT": 31, "NL": 18,
        "NO": 15, "PL": 28, "PT": 25, "RO": 24, "SE": 24, "SI": 19, "SK": 24,
        "SM": 27, "VA": 22
    ]

    /// Toglie spazi e punteggiatura e porta tutto in maiuscolo.
    static func compact(_ raw: String) -> String {
        raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// Spezza l'IBAN in gruppi di quattro caratteri, come si scrive sui moduli.
    static func formatted(_ raw: String) -> String {
        let value = compact(raw)
        var out = ""
        for (index, character) in value.enumerated() {
            if index > 0 && index % 4 == 0 { out.append(" ") }
            out.append(character)
        }
        return out
    }

    /// L'esito della validazione, con il motivo dell'eventuale scarto:
    /// così la schermata può dire *cosa* non va invece di un generico "errore".
    enum ValidationResult: Equatable {
        case valid
        case empty
        case tooShort
        case invalidCountry
        case wrongLength(expected: Int)
        case badCheckDigits

        var isValid: Bool { self == .valid }

        var message: String? {
            switch self {
            case .valid, .empty:
                return nil
            case .tooShort:
                return "IBAN troppo corto"
            case .invalidCountry:
                return "Il codice paese non è valido"
            case .wrongLength(let expected):
                return "Per questo paese servono \(expected) caratteri"
            case .badCheckDigits:
                return "IBAN non valido: controlla le cifre"
            }
        }
    }

    static func validate(_ raw: String) -> ValidationResult {
        let value = compact(raw)

        if value.isEmpty { return .empty }
        if value.count < 15 { return .tooShort }
        if value.count > 34 { return .badCheckDigits }

        let country = String(value.prefix(2))
        guard country.allSatisfy({ $0.isLetter }) else { return .invalidCountry }

        // Le due cifre dopo il paese sono per definizione numeriche.
        let checkDigits = value.dropFirst(2).prefix(2)
        guard checkDigits.allSatisfy({ $0.isNumber }) else { return .badCheckDigits }

        if let expected = lengthsByCountry[country], expected != value.count {
            return .wrongLength(expected: expected)
        }

        return mod97(value) == 1 ? .valid : .badCheckDigits
    }

    static func isValid(_ raw: String) -> Bool {
        validate(raw).isValid
    }

    /// Il calcolo modulo 97 dello standard.
    ///
    /// I primi quattro caratteri vanno in fondo, poi ogni lettera diventa un
    /// numero (A=10 … Z=35) e si divide il tutto per 97: se il resto è 1
    /// l'IBAN è formalmente corretto. Il resto viene aggiornato cifra per
    /// cifra perché il numero completo supererebbe di molto un `Int` a 64 bit.
    private static func mod97(_ value: String) -> Int {
        let rearranged = value.dropFirst(4) + value.prefix(4)
        var remainder = 0

        for character in rearranged {
            if character.isNumber, let digit = character.wholeNumberValue {
                remainder = (remainder * 10 + digit) % 97
            } else if character.isLetter, let ascii = character.asciiValue {
                let mapped = Int(ascii) - 65 + 10
                guard (10...35).contains(mapped) else { return -1 }
                remainder = (remainder * 100 + mapped) % 97
            } else {
                return -1
            }
        }
        return remainder
    }
}
