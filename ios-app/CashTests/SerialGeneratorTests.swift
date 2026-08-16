import XCTest
@testable import Cash

/// Il numero di serie delle banconote.
final class SerialGeneratorTests: XCTestCase {

    func testLength() {
        XCTAssertEqual(SerialGenerator.make().count, 8)
    }

    /// Il requisito che dà senso all'alfabeto scelto: `I`, `O`, `0` e `1`
    /// letti a voce o trascritti a mano si confondono a coppie.
    func testAlphabetExcludesAmbiguousCharacters() {
        for character in SerialGenerator.excludedCharacters {
            XCTAssertFalse(
                SerialGenerator.alphabet.contains(character),
                "L'alfabeto non deve contenere «\(character)»"
            )
        }
    }

    func testAlphabetIsAllUppercaseAlphanumeric() {
        for character in SerialGenerator.alphabet {
            XCTAssertTrue(character.isUppercase || character.isNumber)
        }
    }

    func testGeneratedSerialsOnlyUseTheAlphabet() {
        for _ in 0..<500 {
            let serial = SerialGenerator.make()
            XCTAssertTrue(
                serial.allSatisfy(SerialGenerator.alphabet.contains),
                "Seriale fuori alfabeto: \(serial)"
            )
        }
    }

    func testNoAmbiguousCharacterEverAppears() {
        let produced = (0..<2_000).map { _ in SerialGenerator.make() }.joined()
        for character in SerialGenerator.excludedCharacters {
            XCTAssertFalse(produced.contains(character))
        }
    }

    func testDeterministicWithInjectedGenerator() {
        var index = 0
        let serial = SerialGenerator.make {
            defer { index += 1 }
            return index
        }
        XCTAssertEqual(serial, String(SerialGenerator.alphabet.prefix(8)))
    }

    func testOutOfRangeGeneratorIsClamped() {
        XCTAssertEqual(SerialGenerator.make { -5 }, String(repeating: SerialGenerator.alphabet[0], count: 8))
        XCTAssertEqual(
            SerialGenerator.make { 9_999 },
            String(repeating: SerialGenerator.alphabet[SerialGenerator.alphabet.count - 1], count: 8)
        )
    }

    func testWellFormedCheck() {
        XCTAssertTrue(SerialGenerator.isWellFormed(SerialGenerator.make()))
        XCTAssertFalse(SerialGenerator.isWellFormed("ABC"))
        XCTAssertFalse(SerialGenerator.isWellFormed("ABCDEFGI"))   // contiene I
        XCTAssertFalse(SerialGenerator.isWellFormed("abcd2345"))   // minuscole
    }

    /// Non è un requisito di unicità crittografica, ma due seriali identici
    /// su un campione piccolo indicherebbero un generatore rotto.
    func testCollisionsAreRareOnSmallSamples() {
        let sample = Set((0..<1_000).map { _ in SerialGenerator.make() })
        XCTAssertGreaterThan(sample.count, 990)
    }
}
