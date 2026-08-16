import XCTest
@testable import Cash

/// Il tipo che rappresenta il denaro. Se sbaglia qui, sbaglia ovunque.
final class MoneyTests: XCTestCase {

    // MARK: - Costruzione

    func testUnitsBecomeCents() {
        XCTAssertEqual(Money(units: 250).cents, 25_000)
        XCTAssertEqual(Money(units: 5_000).cents, 500_000)
        XCTAssertEqual(Money(units: 0).cents, 0)
    }

    func testUnitsAndCentsCombine() {
        XCTAssertEqual(Money(units: 12, cents: 50).cents, 1_250)
    }

    func testZero() {
        XCTAssertTrue(Money.zero.isZero)
        XCTAssertEqual(Money.zero.cents, 0)
    }

    // MARK: - Scomposizione

    func testUnitsAndFractionSplit() {
        let amount = Money(cents: 1_234)
        XCTAssertEqual(amount.units, 12)
        XCTAssertEqual(amount.fraction, 34)
        XCTAssertEqual(amount.fractionText, "34")
    }

    func testFractionTextPadsSingleDigit() {
        XCTAssertEqual(Money(cents: 1_205).fractionText, "05")
        XCTAssertEqual(Money(cents: 1_200).fractionText, "00")
    }

    func testNegativeFractionIsUnsigned() {
        XCTAssertEqual(Money(cents: -1_234).fraction, 34)
        XCTAssertEqual(Money(cents: -1_234).fractionText, "34")
    }

    // MARK: - Formattazione

    func testRoundAmountHidesDecimals() {
        XCTAssertEqual(Money(units: 20).formatted(currency: .eur), "€20")
    }

    func testNonRoundAmountShowsDecimals() {
        XCTAssertEqual(Money(cents: 2_050).formatted(currency: .eur), "€20,50")
    }

    func testExactFormattingAlwaysShowsDecimals() {
        XCTAssertEqual(Money(units: 20).formattedExact(currency: .eur), "€20,00")
    }

    func testThousandsSeparator() {
        XCTAssertEqual(Money(units: 1_200).formatted(currency: .eur), "€1.200")
        XCTAssertEqual(Money(units: 1_200).formatted(currency: .usd), "$1,200")
    }

    func testNegativeAmountKeepsSignBeforeSymbol() {
        XCTAssertEqual(Money(cents: -500).formatted(currency: .eur), "-€5")
    }

    func testCurrencySwitchChangesSymbolAndSeparator() {
        let amount = Money(cents: 2_050)
        XCTAssertEqual(amount.formatted(currency: .eur), "€20,50")
        XCTAssertEqual(amount.formatted(currency: .cad), "$20.50")
    }

    // MARK: - Aritmetica

    func testAddingAndSubtracting() throws {
        let a = Money(units: 10)
        let b = Money(cents: 250)
        XCTAssertEqual(try a.adding(b).cents, 1_250)
        XCTAssertEqual(try a.subtracting(b).cents, 750)
    }

    func testAddingReportsOverflow() {
        let huge = Money(cents: Int64.max)
        XCTAssertThrowsError(try huge.adding(Money(cents: 1))) { error in
            XCTAssertEqual(error as? Money.ArithmeticError, .overflow)
        }
    }

    func testSubtractingReportsOverflow() {
        let lowest = Money(cents: Int64.min)
        XCTAssertThrowsError(try lowest.subtracting(Money(cents: 1))) { error in
            XCTAssertEqual(error as? Money.ArithmeticError, .overflow)
        }
    }

    // MARK: - Passo con saturazione

    func testSteppingStaysInsideRange() {
        let range = AppConfiguration.amountRange

        XCTAssertEqual(Money(units: 20).stepped(by: 100, clampedTo: range), Money(units: 21))
        XCTAssertEqual(Money(units: 20).stepped(by: -1, clampedTo: range), Money(cents: 1_999))
    }

    func testSteppingNeverGoesNegative() {
        let range = AppConfiguration.amountRange
        XCTAssertEqual(Money.zero.stepped(by: -100, clampedTo: range), .zero)
        XCTAssertEqual(Money(cents: 50).stepped(by: -100, clampedTo: range), .zero)
    }

    func testSteppingNeverExceedsMaximum() {
        let range = AppConfiguration.amountRange
        let maximum = AppConfiguration.maximumPayment

        XCTAssertEqual(maximum.stepped(by: 100, clampedTo: range), maximum)
        XCTAssertEqual(maximum.stepped(by: 1, clampedTo: range), maximum)
    }

    func testSteppingSaturatesInsteadOfOverflowing() {
        let range = AppConfiguration.amountRange
        XCTAssertEqual(
            Money(cents: Int64.max).stepped(by: Int64.max, clampedTo: range),
            AppConfiguration.maximumPayment
        )
    }

    // MARK: - Confronto e codifica

    func testComparable() {
        XCTAssertTrue(Money(units: 10) < Money(units: 20))
        XCTAssertTrue(Money(cents: 1_999) < Money(units: 20))
        XCTAssertFalse(Money(units: 20) < Money(units: 20))
    }

    func testCodableRoundTrip() throws {
        let original = Money(cents: 123_456)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(Money.self, from: data), original)
    }

    func testDecimalNumberForPassKit() {
        XCTAssertEqual(Money(cents: 2_050).decimalNumber.stringValue, "20.5")
        XCTAssertEqual(Money(units: 20).decimalNumber.doubleValue, 20.0, accuracy: 0.0001)
    }
}
