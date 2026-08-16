import XCTest
@testable import Cash

/// Lo stato dell'app: conto, onboarding, firma, movimenti.
@MainActor
final class AppStateTests: XCTestCase {

    private var persistence: InMemoryStore!
    private var keychain: InMemorySecureStore!

    override func setUp() {
        super.setUp()
        persistence = InMemoryStore()
        keychain = InMemorySecureStore()
    }

    private func makeState() -> AppState {
        AppState(persistence: persistence, secureStore: keychain)
    }

    // MARK: - Onboarding

    func testFreshInstallNeedsOnboarding() {
        let state = makeState()

        XCTAssertNil(state.account)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertFalse(state.isReadyToPay)
    }

    /// **La regola del Portachiavi.** Le preferenze dicono che l'onboarding
    /// era stato fatto, ma il conto non c'è più — è quello che succede dopo un
    /// ripristino da backup, perché il Portachiavi è `ThisDeviceOnly`. Senza
    /// coordinate l'app non ha nulla a cui agganciare i pagamenti: si rifà.
    func testOnboardingIsRedoneWhenTheKeychainLostTheAccount() {
        persistence.storedOnboarding = true   // preferenze: fatto
        // keychain: vuoto

        let state = makeState()

        XCTAssertNil(state.account)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertFalse(state.isReadyToPay)
    }

    func testLinkingAnAccountCompletesOnboarding() {
        let state = makeState()
        state.link(account: BankAccount(
            holderName: "Giovanni Maffei",
            iban: "IT60X0542811101000000123456"
        ))

        XCTAssertNotNil(state.account)
        XCTAssertTrue(state.hasCompletedOnboarding)
        XCTAssertTrue(state.isReadyToPay)
        XCTAssertTrue(persistence.storedOnboarding)
    }

    func testLinkedAccountIsRestoredOnNextLaunch() {
        let first = makeState()
        first.link(account: BankAccount(
            holderName: "Giovanni Maffei",
            iban: "IT60X0542811101000000123456"
        ))

        let second = makeState()
        XCTAssertEqual(second.account?.iban, "IT60X0542811101000000123456")
        XCTAssertTrue(second.isReadyToPay)
    }

    func testKeychainFailureIsSurfacedAndNothingIsLinked() {
        let state = makeState()
        keychain.failNextSave = true

        state.link(account: BankAccount(holderName: "Giovanni", iban: "IT60X0542811101000000123456"))

        XCTAssertNil(state.account)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertNotNil(state.alert)
    }

    func testUnlinkingClearsEverythingAboutTheAccount() {
        let state = makeState()
        state.link(account: BankAccount(holderName: "Giovanni", iban: "IT60X0542811101000000123456"))
        state.unlinkAccount()

        XCTAssertNil(state.account)
        XCTAssertFalse(state.isReadyToPay)
        XCTAssertFalse(keychain.contains("cash.bank-account"))
    }

    // MARK: - Firma

    func testSignatureIsDerivedFromTheHolderName() {
        let state = makeState()
        state.link(account: BankAccount(
            holderName: "Giovanni Maffei",
            iban: "IT60X0542811101000000123456"
        ))

        XCTAssertEqual(state.signature, "@GIOVANNI")
    }

    func testAChosenSignatureIsNotOverwritten() {
        let state = makeState()
        state.updateSignature("BEN")
        state.link(account: BankAccount(
            holderName: "Giovanni Maffei",
            iban: "IT60X0542811101000000123456"
        ))

        XCTAssertEqual(state.signature, "@BEN")
    }

    func testSignatureNormalization() {
        XCTAssertEqual(UserSignature.normalize("Giovanni"), "@GIOVANNI")
        XCTAssertEqual(UserSignature.normalize("@giovanni"), "@GIOVANNI")
        XCTAssertEqual(UserSignature.normalize("@@gio vanni!"), "@GIOVANNI")
        XCTAssertEqual(UserSignature.normalize("ben_giannis"), "@BEN_GIANNIS")
        XCTAssertEqual(UserSignature.normalize(""), "@ME")
        XCTAssertEqual(UserSignature.normalize("   "), "@ME")
        XCTAssertEqual(UserSignature.normalize("!!!"), "@ME")
    }

    func testSignatureIsTruncated() {
        let long = UserSignature.normalize(String(repeating: "A", count: 40))
        XCTAssertEqual(long.count, UserSignature.maximumLength + 1)   // + la chiocciola
    }

    func testSignatureSurvivesRelaunch() {
        makeState().updateSignature("Ben")
        XCTAssertEqual(makeState().signature, "@BEN")
    }

    // MARK: - Movimenti

    func testCommitReducesBalanceAndAppendsToHistory() {
        let state = makeState()
        state.link(account: BankAccount(holderName: "G", iban: "IT60X0542811101000000123456"))

        let draft = PaymentDraft(recipient: .fixture(), amount: Money(units: 20))
        let result = state.commit(draft)

        guard case .success = result else { return XCTFail("Doveva riuscire") }
        XCTAssertEqual(state.balance, Money(units: 230))
        XCTAssertEqual(state.transactions.count, 1)
    }

    /// Il nome nello storico è una copia congelata: il contatto può sparire
    /// dalla rubrica, la riga deve continuare a dire chi era.
    func testHistoryKeepsTheNameEvenIfTheContactDisappears() {
        let state = makeState()
        state.link(account: BankAccount(holderName: "G", iban: "IT60X0542811101000000123456"))

        var contact: ContactPerson? = .fixture(given: "Natalie", family: "Rossi")
        state.commit(PaymentDraft(recipient: contact!, amount: Money(units: 20)))
        contact = nil

        XCTAssertEqual(state.transactions.first?.counterpartName, "Natalie Rossi")
    }

    func testValidateRefusesWithoutAnAccount() {
        let state = makeState()
        XCTAssertEqual(state.validate(amount: Money(units: 10)), "Collega prima un conto")
    }

    func testDeletingATransactionRestoresTheBalance() {
        let state = makeState()
        state.link(account: BankAccount(holderName: "G", iban: "IT60X0542811101000000123456"))
        state.commit(PaymentDraft(recipient: .fixture(), amount: Money(units: 20)))

        let id = state.transactions[0].id
        state.deleteTransaction(id: id)

        XCTAssertEqual(state.balance, AppConfiguration.initialBalance)
        XCTAssertTrue(state.transactions.isEmpty)
    }

    func testReceivingIncreasesBalance() {
        let state = makeState()
        state.receive(from: "Marco", amount: Money(units: 40))

        XCTAssertEqual(state.balance, Money(units: 290))
        XCTAssertEqual(state.transactions.first?.direction, .received)
    }

    func testResetClearsAccountHistoryAndSignature() {
        let state = makeState()
        state.link(account: BankAccount(holderName: "Giovanni", iban: "IT60X0542811101000000123456"))
        state.commit(PaymentDraft(recipient: .fixture(), amount: Money(units: 20)))

        state.resetEverything()

        XCTAssertNil(state.account)
        XCTAssertFalse(state.hasCompletedOnboarding)
        XCTAssertTrue(state.transactions.isEmpty)
        XCTAssertEqual(state.balance, AppConfiguration.initialBalance)
        XCTAssertEqual(state.signature, UserSignature.fallback)
    }

    // MARK: - Conto

    func testMaskedIBANRevealsOnlyTheLastFour() {
        let account = BankAccount(holderName: "G", iban: "IT60X0542811101000000123456")
        XCTAssertEqual(account.maskedIBAN, "IT•• •••• •••• 3456")
        XCTAssertEqual(account.lastFour, "3456")
        XCTAssertEqual(account.countryCode, "IT")
    }

    func testAccountStoresTheCompactedIBAN() {
        let account = BankAccount(holderName: " Giovanni ", iban: "it60 x054 2811 1010 0000 0123 456")
        XCTAssertEqual(account.iban, "IT60X0542811101000000123456")
        XCTAssertEqual(account.holderName, "Giovanni")
    }
}
