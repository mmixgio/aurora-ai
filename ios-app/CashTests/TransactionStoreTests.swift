import XCTest
@testable import Cash

/// Il libro mastro: saldo derivato, duplicati, limiti, persistenza.
final class TransactionStoreTests: XCTestCase {

    private var persistence: InMemoryStore!
    private var store: TransactionStore!

    override func setUp() {
        super.setUp()
        persistence = InMemoryStore()
        store = TransactionStore(persistence: persistence)
    }

    override func tearDown() {
        store = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Stato iniziale

    func testStartsWithInitialBalanceAndEmptyHistory() {
        XCTAssertEqual(store.balance, AppConfiguration.initialBalance)
        XCTAssertTrue(store.transactions.isEmpty)
        XCTAssertNil(store.loadError)
    }

    func testEmptyHistoryHasNoRecentCounterparts() {
        XCTAssertTrue(store.recentCounterparts().isEmpty)
    }

    // MARK: - Saldo derivato

    func testSendingReducesBalance() throws {
        try store.record(.fixture(amount: Money(units: 20)))
        XCTAssertEqual(store.balance, Money(units: 230))
    }

    func testReceivingIncreasesBalance() throws {
        try store.record(.fixture(direction: .received, amount: Money(units: 30)))
        XCTAssertEqual(store.balance, Money(units: 280))
    }

    func testBalanceIsTheSumOfEverything() throws {
        try store.record(.fixture(amount: Money(units: 20)))
        try store.record(.fixture(amount: Money(cents: 1_050)))
        try store.record(.fixture(direction: .received, amount: Money(units: 5)))

        // 250 - 20 - 10,50 + 5 = 224,50
        XCTAssertEqual(store.balance, Money(cents: 22_450))
    }

    /// La conseguenza diretta del saldo derivato: eliminare una riga annulla
    /// il suo effetto, e non c'è modo che le due verità divergano.
    func testDeletingRestoresTheBalanceExactly() throws {
        let before = store.balance
        let transaction = Transaction.fixture(amount: Money(units: 20))

        try store.record(transaction)
        XCTAssertNotEqual(store.balance, before)

        try store.remove(id: transaction.id)
        XCTAssertEqual(store.balance, before)
        XCTAssertTrue(store.transactions.isEmpty)
    }

    func testDeletingAnUnknownIdIsHarmless() throws {
        try store.record(.fixture())
        let before = store.balance

        try store.remove(id: UUID())

        XCTAssertEqual(store.balance, before)
        XCTAssertEqual(store.transactions.count, 1)
    }

    func testComputeBalanceIsPure() {
        let transactions = [
            Transaction.fixture(amount: Money(units: 20)),
            Transaction.fixture(direction: .received, amount: Money(units: 5))
        ]
        XCTAssertEqual(
            TransactionStore.computeBalance(opening: Money(units: 100), transactions: transactions),
            Money(units: 85)
        )
    }

    // MARK: - Validazione

    func testZeroAmountIsRejected() {
        XCTAssertEqual(store.validatePayment(amount: .zero), .amountNotPositive)
    }

    func testNegativeAmountIsRejected() {
        XCTAssertEqual(store.validatePayment(amount: Money(cents: -1)), .amountNotPositive)
    }

    func testMaximumAmountIsAccepted() {
        // Il tetto è incluso: 5.000 € esatti devono passare.
        persistence.storedOpeningBalance = Money(units: 10_000)
        store = TransactionStore(persistence: persistence)

        XCTAssertNil(store.validatePayment(amount: Money(units: 5_000)))
    }

    func testJustAboveMaximumIsRejected() {
        persistence.storedOpeningBalance = Money(units: 10_000)
        store = TransactionStore(persistence: persistence)

        XCTAssertEqual(
            store.validatePayment(amount: Money(cents: 500_001)),
            .aboveLimit(maximum: AppConfiguration.maximumPayment)
        )
    }

    func testInsufficientFunds() {
        let issue = store.validatePayment(amount: Money(units: 300))
        XCTAssertEqual(
            issue,
            .insufficientFunds(available: AppConfiguration.initialBalance, requested: Money(units: 300))
        )
    }

    func testPayingExactlyTheWholeBalanceIsAllowed() throws {
        try store.record(.fixture(amount: AppConfiguration.initialBalance))
        XCTAssertEqual(store.balance, .zero)
    }

    func testZeroBalanceRejectsAnyPayment() throws {
        try store.record(.fixture(amount: AppConfiguration.initialBalance))
        XCTAssertEqual(store.balance, .zero)

        XCTAssertEqual(
            store.validatePayment(amount: Money(cents: 1)),
            .insufficientFunds(available: .zero, requested: Money(cents: 1))
        )
    }

    func testRecordingBeyondBalanceThrows() {
        XCTAssertThrowsError(try store.record(.fixture(amount: Money(units: 300)))) { error in
            guard case .insufficientFunds = error as? TransactionStore.StoreError else {
                return XCTFail("Errore inatteso: \(error)")
            }
        }
        XCTAssertTrue(store.transactions.isEmpty)
        XCTAssertEqual(store.balance, AppConfiguration.initialBalance)
    }

    /// Il denaro in entrata non è soggetto al controllo di capienza.
    func testReceivingIsNotLimitedByBalance() throws {
        try store.record(.fixture(direction: .received, amount: Money(units: 4_000)))
        XCTAssertEqual(store.balance, Money(units: 4_250))
    }

    // MARK: - Duplicati

    /// Un tocco doppio, o una schermata riaperta, non deve poter addebitare
    /// due volte lo stesso pagamento.
    func testDuplicateTransactionIsRejected() throws {
        let transaction = Transaction.fixture(amount: Money(units: 20))
        try store.record(transaction)

        XCTAssertThrowsError(try store.record(transaction)) { error in
            XCTAssertEqual(
                error as? TransactionStore.StoreError,
                .duplicateTransaction(transaction.id)
            )
        }

        XCTAssertEqual(store.transactions.count, 1)
        XCTAssertEqual(store.balance, Money(units: 230))
    }

    func testSameAmountDifferentIdIsAllowed() throws {
        try store.record(.fixture(amount: Money(units: 20)))
        try store.record(.fixture(amount: Money(units: 20)))
        XCTAssertEqual(store.transactions.count, 2)
    }

    // MARK: - Ordinamento e recenti

    func testMostRecentFirst() throws {
        let first = Transaction.fixture(name: "Marco")
        let second = Transaction.fixture(name: "Giulia")

        try store.record(first)
        try store.record(second)

        XCTAssertEqual(store.transactions.first?.counterpartName, "Giulia")
    }

    func testRecentCounterpartsAreUniqueAndOrdered() throws {
        try store.record(.fixture(name: "Marco", amount: Money(units: 1)))
        try store.record(.fixture(name: "Giulia", amount: Money(units: 1)))
        try store.record(.fixture(name: "Marco", amount: Money(units: 1)))

        XCTAssertEqual(store.recentCounterparts(), ["Marco", "Giulia"])
    }

    func testRecentCounterpartsRespectTheLimit() throws {
        for index in 0..<12 {
            try store.record(.fixture(name: "Persona \(index)", amount: Money(units: 1)))
        }
        XCTAssertEqual(store.recentCounterparts(limit: 8).count, 8)
    }

    // MARK: - Persistenza

    func testTransactionsSurviveAReload() throws {
        try store.record(.fixture(amount: Money(units: 20)))

        let reloaded = TransactionStore(persistence: persistence)
        XCTAssertEqual(reloaded.transactions.count, 1)
        XCTAssertEqual(reloaded.balance, Money(units: 230))
    }

    /// Uno storico illeggibile non deve impedire l'avvio, ma nemmeno passare
    /// sotto silenzio.
    func testUnreadableHistoryStartsEmptyAndReportsTheError() {
        persistence.loadError = .decodingFailed("lo storico")

        let recovering = TransactionStore(persistence: persistence)

        XCTAssertTrue(recovering.transactions.isEmpty)
        XCTAssertEqual(recovering.loadError, .decodingFailed("lo storico"))
        XCTAssertEqual(recovering.balance, AppConfiguration.initialBalance)
    }

    func testSaveFailureIsSurfacedAndStateStaysConsistent() {
        persistence.saveError = .encodingFailed("lo storico")

        XCTAssertThrowsError(try store.record(.fixture(amount: Money(units: 20)))) { error in
            XCTAssertEqual(
                error as? TransactionStore.StoreError,
                .persistence(.encodingFailed("lo storico"))
            )
        }
    }

    func testResetClearsEverything() throws {
        try store.record(.fixture(amount: Money(units: 20)))
        store.reset()

        XCTAssertTrue(store.transactions.isEmpty)
        XCTAssertEqual(store.balance, AppConfiguration.initialBalance)
    }
}
