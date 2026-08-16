import Foundation

/// Validazione degli IBAN secondo lo standard ISO 13616.
///
/// Il controllo è quello vero: normalizzazione, codice paese, cifre di
/// controllo, lunghezza attesa per il paese e modulo 97. Non garantisce che
/// il conto esista — nessun algoritmo può — ma scarta tutto ciò che è
/// formalmente impossibile.
enum IBANValidator {

    /// Perché un IBAN è stato scartato.
    ///
    /// Ogni caso porta con sé quello che serve a scrivere un messaggio utile:
    /// "per questo paese servono 27 caratteri" invece di "IBAN non valido".
    enum ValidationError: Error, Equatable {
        case empty
        case tooShort(minimum: Int)
        case tooLong(maximum: Int)
        case invalidCountryCode
        case nonNumericCheckDigits
        case wrongLength(country: String, expected: Int, found: Int)
        case invalidCharacter(Character)
        case checksumMismatch

        var message: String {
            switch self {
            case .empty:
                return "Inserisci un IBAN"
            case .tooShort(let minimum):
                return "Un IBAN ha almeno \(minimum) caratteri"
            case .tooLong(let maximum):
                return "Un IBAN non supera i \(maximum) caratteri"
            case .invalidCountryCode:
                return "Le prime due lettere devono essere un codice paese"
            case .nonNumericCheckDigits:
                return "Il terzo e quarto carattere devono essere cifre"
            case .wrongLength(let country, let expected, let found):
                return "Per \(country) servono \(expected) caratteri, ne hai messi \(found)"
            case .invalidCharacter(let character):
                return "Il carattere «\(character)» non può stare in un IBAN"
            case .checksumMismatch:
                return "IBAN non valido: controlla le cifre"
            }
        }
    }

    static let minimumLength = 15
    static let maximumLength = 34

    /// Lunghezza esatta dell'IBAN per paese.
    ///
    /// Un paese non elencato non viene rifiutato: passa se la cifra di
    /// controllo torna. Meglio accettare un IBAN estero valido che non
    /// conosciamo, che rifiutare un utente per una tabella incompleta.
    static let expectedLengths: [String: Int] = [
        "AD": 24, "AE": 23, "AL": 28, "AT": 20, "AZ": 28, "BA": 20, "BE": 16,
        "BG": 22, "BH": 22, "BR": 29, "BY": 28, "CH": 21, "CR": 22, "CY": 28,
        "CZ": 24, "DE": 22, "DK": 18, "DO": 28, "EE": 20, "EG": 29, "ES": 24,
        "FI": 18, "FO": 18, "FR": 27, "GB": 22, "GE": 22, "GI": 23, "GL": 18,
        "GR": 27, "GT": 28, "HR": 21, "HU": 28, "IE": 22, "IL": 23, "IS": 26,
        "IT": 27, "JO": 30, "KW": 30, "KZ": 20, "LB": 28, "LC": 32, "LI": 21,
        "LT": 20, "LU": 20, "LV": 21, "MC": 27, "MD": 24, "ME": 22, "MK": 19,
        "MR": 27, "MT": 31, "MU": 30, "NL": 18, "NO": 15, "PK": 24, "PL": 28,
        "PS": 29, "PT": 25, "QA": 29, "RO": 24, "RS": 22, "SA": 24, "SE": 24,
        "SI": 19, "SK": 24, "SM": 27, "TN": 24, "TR": 26, "UA": 29, "VA": 22,
        "VG": 24, "XK": 20
    ]

    /// Toglie tutto ciò che non è lettera o cifra ASCII e porta in maiuscolo.
    static func compact(_ raw: String) -> String {
        raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    /// Spezza in gruppi di quattro, come si scrive sui moduli.
    /// `IT60X0542811101000000123456` → `IT60 X054 2811 1010 0000 0123 456`
    static func formatted(_ raw: String) -> String {
        let value = compact(raw)
        var out = ""
        for (index, character) in value.enumerated() {
            if index > 0 && index % 4 == 0 { out.append(" ") }
            out.append(character)
        }
        return out
    }

    /// Valida, oppure spiega perché no.
    static func validate(_ raw: String) -> Result<String, ValidationError> {
        let value = compact(raw)

        guard !value.isEmpty else { return .failure(.empty) }
        guard value.count >= minimumLength else {
            return .failure(.tooShort(minimum: minimumLength))
        }
        guard value.count <= maximumLength else {
            return .failure(.tooLong(maximum: maximumLength))
        }

        let country = String(value.prefix(2))
        guard country.allSatisfy(\.isLetter) else {
            return .failure(.invalidCountryCode)
        }

        guard value.dropFirst(2).prefix(2).allSatisfy(\.isNumber) else {
            return .failure(.nonNumericCheckDigits)
        }

        if let expected = expectedLengths[country], expected != value.count {
            return .failure(.wrongLength(
                country: country,
                expected: expected,
                found: value.count
            ))
        }

        switch modulo97(value) {
        case .success(let remainder):
            return remainder == 1 ? .success(value) : .failure(.checksumMismatch)
        case .failure(let error):
            return .failure(error)
        }
    }

    static func isValid(_ raw: String) -> Bool {
        if case .success = validate(raw) { return true }
        return false
    }

    /// Il modulo 97 dello standard, calcolato in modo incrementale.
    ///
    /// I primi quattro caratteri vanno in fondo, poi ogni lettera diventa un
    /// numero (A=10 … Z=35) e si divide il tutto per 97. Il resto viene
    /// aggiornato **cifra per cifra**: l'IBAN convertito per intero sarebbe un
    /// numero da oltre trenta cifre, che non entra in nessun intero nativo.
    ///
    /// Una lettera vale due posizioni decimali (diventa un numero a due
    /// cifre), quindi il resto si moltiplica per 100 e non per 10.
    static func modulo97(_ compacted: String) -> Result<Int, ValidationError> {
        let rearranged = compacted.dropFirst(4) + compacted.prefix(4)
        var remainder = 0

        for character in rearranged {
            if character.isNumber, let digit = character.wholeNumberValue, digit < 10 {
                remainder = (remainder * 10 + digit) % 97
            } else if character.isASCII, character.isLetter, let ascii = character.asciiValue {
                let mapped = Int(ascii) - 65 + 10
                guard (10...35).contains(mapped) else {
                    return .failure(.invalidCharacter(character))
                }
                remainder = (remainder * 100 + mapped) % 97
            } else {
                return .failure(.invalidCharacter(character))
            }
        }

        return .success(remainder)
    }
}
