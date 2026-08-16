import XCTest
@testable import Cash

/// Il colore dell'avatar per chi non ha una foto.
final class DeterministicColorTests: XCTestCase {

    /// Il requisito centrale: stesso nome, stesso colore, sempre. Se qui si
    /// usasse `hashValue` questo test fallirebbe fra un avvio e l'altro,
    /// perché Swift lo randomizza di proposito.
    func testSameNameAlwaysProducesSameHue() {
        let first = DeterministicColor.hue(for: "Natalie Rossi")
        for _ in 0..<100 {
            XCTAssertEqual(DeterministicColor.hue(for: "Natalie Rossi"), first)
        }
    }

    func testDifferentNamesUsuallyProduceDifferentHues() {
        let names = ["Natalie Rossi", "Marco Bianchi", "Giulia Verdi", "Luca Neri"]
        let hues = Set(names.map(DeterministicColor.hue(for:)))
        XCTAssertGreaterThan(hues.count, 1)
    }

    func testHueStaysInUnitRange() {
        let names = ["", "A", "Zzzzzzzzzz", "Ludovico Einaudi", "李雷", "Ægir"]
        for name in names {
            let hue = DeterministicColor.hue(for: name)
            XCTAssertGreaterThanOrEqual(hue, 0)
            XCTAssertLessThan(hue, 1)
        }
    }

    func testEmptyNameDoesNotCrashAndIsStable() {
        XCTAssertEqual(DeterministicColor.hue(for: ""), 0)
    }

    func testCaseChangesTheColour() {
        // Non è un requisito, ma documenta il comportamento: il nome viene
        // usato così com'è, quindi "natalie" e "Natalie" sono due chiavi.
        XCTAssertNotEqual(
            DeterministicColor.hue(for: "natalie"),
            DeterministicColor.hue(for: "Natalie")
        )
    }

    func testGradientComponentsShareTheHue() {
        let components = DeterministicColor.gradientComponents(for: "Natalie Rossi")
        XCTAssertEqual(components.top.hue, components.bottom.hue)
        XCTAssertGreaterThan(components.top.brightness, components.bottom.brightness)
    }

    // MARK: - Iniziali

    func testInitialsFromFullName() {
        XCTAssertEqual(ContactPerson.initials(for: "Natalie Rossi"), "NR")
    }

    func testInitialsFromSingleName() {
        XCTAssertEqual(ContactPerson.initials(for: "Natalie"), "N")
    }

    func testInitialsFromEmptyName() {
        XCTAssertEqual(ContactPerson.initials(for: ""), "?")
    }

    func testInitialsUseAtMostTwoLetters() {
        XCTAssertEqual(ContactPerson.initials(for: "Anna Maria De Luca"), "AM")
    }
}
