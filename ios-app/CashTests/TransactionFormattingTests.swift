import XCTest
@testable import Cash

/// Come i movimenti si presentano a schermo.
final class TransactionFormattingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    func testSignedAmountText() {
        XCTAssertEqual(
            Transaction.fixture(direction: .sent, amount: Money(units: 20)).signedAmountText,
            "-€20"
        )
        XCTAssertEqual(
            Transaction.fixture(direction: .received, amount: Money(cents: 2_050)).signedAmountText,
            "+€20,50"
        )
    }

    func testBalanceEffectSign() {
        XCTAssertEqual(
            Transaction.fixture(direction: .sent, amount: Money(units: 20)).balanceEffectInCents,
            -2_000
        )
        XCTAssertEqual(
            Transaction.fixture(direction: .received, amount: Money(units: 20)).balanceEffectInCents,
            2_000
        )
    }

    func testTodayAndYesterdayAreNamed() {
        let today = TransactionRow.dateText(for: Date(), calendar: calendar)
        XCTAssertTrue(today.hasPrefix("Oggi "), today)

        let yesterday = TransactionRow.dateText(
            for: Date().addingTimeInterval(-86_400),
            calendar: calendar
        )
        XCTAssertTrue(yesterday.hasPrefix("Ieri "), yesterday)
    }

    func testOlderDatesUseTheExtendedForm() {
        let old = TransactionRow.dateText(
            for: Date().addingTimeInterval(-86_400 * 10),
            calendar: calendar
        )
        XCTAssertFalse(old.hasPrefix("Oggi"))
        XCTAssertFalse(old.hasPrefix("Ieri"))
    }

    func testInitialsComeFromTheFrozenName() {
        XCTAssertEqual(Transaction.fixture(name: "Natalie Rossi").initials, "NR")
    }

    func testCodableRoundTripKeepsEverything() throws {
        let original = Transaction.fixture(amount: Money(cents: 12_345))
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(Transaction.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.serial, original.serial)
        XCTAssertEqual(decoded.amount.cents, 12_345)
    }

    // MARK: - Contatti

    func testPresentableFiltersEmptyCards() {
        XCTAssertFalse(ContactPerson(id: "1").isPresentable)
        XCTAssertTrue(ContactPerson(id: "2", givenName: "Natalie").isPresentable)
        XCTAssertTrue(ContactPerson(id: "3", organizationName: "Acme").isPresentable)
    }

    func testDisplayNameFallsBackInOrder() {
        XCTAssertEqual(ContactPerson(id: "1", givenName: "Natalie", familyName: "Rossi").displayName, "Natalie")
        XCTAssertEqual(ContactPerson(id: "2", familyName: "Rossi").displayName, "Rossi")
        XCTAssertEqual(ContactPerson(id: "3", organizationName: "Acme").displayName, "Acme")
        XCTAssertEqual(ContactPerson(id: "4").displayName, "Sconosciuto")
    }

    func testFullNameJoinsWhatExists() {
        XCTAssertEqual(ContactPerson(id: "1", givenName: "Natalie", familyName: "Rossi").fullName, "Natalie Rossi")
        XCTAssertEqual(ContactPerson(id: "2", givenName: "Natalie").fullName, "Natalie")
        XCTAssertEqual(ContactPerson(id: "3").fullName, "Sconosciuto")
    }
}
