import XCTest
@testable import Cash

/// Validazione IBAN secondo ISO 13616.
///
/// I vettori usati qui sono IBAN di esempio pubblici, verificati a parte:
/// un test che parte da un dato sbagliato è peggio di nessun test.
final class IBANValidatorTests: XCTestCase {

    // MARK: - Normalizzazione e formato

    func testCompactRemovesSpacesAndPunctuation() {
        XCTAssertEqual(
            IBANValidator.compact("it60 x054-2811.1010 0000 0123 456"),
            "IT60X0542811101000000123456"
        )
    }

    func testFormattedGroupsByFour() {
        XCTAssertEqual(
            IBANValidator.formatted("IT60X0542811101000000123456"),
            "IT60 X054 2811 1010 0000 0123 456"
        )
    }

    func testFormattingIsIdempotent() {
        let once = IBANValidator.formatted("IT60X0542811101000000123456")
        XCTAssertEqual(IBANValidator.formatted(once), once)
    }

    // MARK: - IBAN validi

    func testValidItalianIBAN() {
        XCTAssertTrue(IBANValidator.isValid("IT60X0542811101000000123456"))
        XCTAssertTrue(IBANValidator.isValid("IT40S0542811101000000123456"))
    }

    func testValidIBANWithUserSpacing() {
        XCTAssertTrue(IBANValidator.isValid("IT60 X054 2811 1010 0000 0123 456"))
    }

    func testValidIBANFromOtherCountriesWithDifferentLengths() {
        // Lunghezze diverse fra loro: 15, 18, 21, 22, 24, 27, 31.
        let valid = [
            "NO9386011117947",                  // 15
            "NL91ABNA0417164300",               // 18
            "CH9300762011623852957",            // 21
            "DE89370400440532013000",           // 22
            "GB82WEST12345698765432",           // 22
            "ES9121000418450200051332",         // 24
            "FR1420041010050500013M02606",      // 27
            "MT84MALT011000012345MTLCAST001S"   // 31
        ]

        for iban in valid {
            XCTAssertTrue(IBANValidator.isValid(iban), "Doveva essere valido: \(iban)")
        }
    }

    func testValidationReturnsCompactedValue() {
        guard case .success(let compacted) = IBANValidator.validate("it60 x054 2811 1010 0000 0123 456") else {
            return XCTFail("Doveva essere valido")
        }
        XCTAssertEqual(compacted, "IT60X0542811101000000123456")
    }

    // MARK: - IBAN non validi, con il motivo giusto

    func testEmptyInput() {
        XCTAssertEqual(error(for: ""), .empty)
        XCTAssertEqual(error(for: "   "), .empty)
    }

    func testTooShort() {
        XCTAssertEqual(error(for: "IT60X054"), .tooShort(minimum: 15))
    }

    func testTooLong() {
        let overlong = "IT" + String(repeating: "0", count: 40)
        XCTAssertEqual(error(for: overlong), .tooLong(maximum: 34))
    }

    func testInvalidCountryCode() {
        XCTAssertEqual(error(for: "1T60X0542811101000000123456"), .invalidCountryCode)
    }

    func testNonNumericCheckDigits() {
        XCTAssertEqual(error(for: "ITX0X0542811101000000123456"), .nonNumericCheckDigits)
    }

    /// Il caso che il messaggio deve spiegare: giusto il paese, sbagliata la
    /// lunghezza. All'utente serve sapere *quanti* caratteri servono.
    func testItalianIBANWithWrongLength() {
        let result = error(for: "IT60X05428111010000001234")   // 25 invece di 27
        XCTAssertEqual(result, .wrongLength(country: "IT", expected: 27, found: 25))
        XCTAssertEqual(result?.message, "Per IT servono 27 caratteri, ne hai messi 25")
    }

    func testItalianIBANWithBrokenChecksum() {
        XCTAssertEqual(error(for: "IT99X0542811101000000123456"), .checksumMismatch)
    }

    func testSingleAlteredDigitIsRejected() {
        // Una cifra cambiata in mezzo: è esattamente il caso che il modulo 97
        // esiste per intercettare.
        XCTAssertFalse(IBANValidator.isValid("IT60X0542811101000000123457"))
    }

    // MARK: - Modulo 97

    func testModulo97OfValidIBANIsOne() {
        guard case .success(let remainder) = IBANValidator.modulo97("IT60X0542811101000000123456") else {
            return XCTFail("Il calcolo non doveva fallire")
        }
        XCTAssertEqual(remainder, 1)
    }

    func testModulo97RejectsNonAlphanumeric() {
        guard case .failure(let error) = IBANValidator.modulo97("IT60X05428111010000001234!6") else {
            return XCTFail("Doveva rifiutare il carattere")
        }
        XCTAssertEqual(error, .invalidCharacter("!"))
    }

    /// Il numero completo di un IBAN a 34 caratteri supera i 10^38: se
    /// l'implementazione provasse a costruirlo in un intero, qui esploderebbe.
    func testLongestIBANDoesNotOverflow() {
        let longest = "MT84MALT011000012345MTLCAST001S"
        XCTAssertTrue(IBANValidator.isValid(longest))
    }

    // MARK: - Aiuto

    private func error(for input: String) -> IBANValidator.ValidationError? {
        if case .failure(let error) = IBANValidator.validate(input) { return error }
        return nil
    }
}
