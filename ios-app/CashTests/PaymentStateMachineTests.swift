import XCTest
@testable import Cash

/// La macchina a stati del pagamento.
///
/// Gira con un orologio immediato, un autorizzatore pilotabile e un registro
/// finto: nessun Face ID, nessuna attesa reale, nessun disco.
@MainActor
final class PaymentStateMachineTests: XCTestCase {

    private var ledger: StubLedger!
    private var authorizer: StubAuthorizer!
    private var volume: StubVolumeService!
    private var model: PaymentViewModel!

    override func setUp() {
        super.setUp()
        ledger = StubLedger()
        authorizer = StubAuthorizer()
        volume = StubVolumeService()
        model = makeModel()
    }

    private func makeModel() -> PaymentViewModel {
        PaymentViewModel(
            recipient: .fixture(),
            ledger: ledger,
            authorizer: authorizer,
            volume: volume,
            clock: ImmediatePaymentClock()
        )
    }

    // MARK: - Stato iniziale

    func testStartsOnAmountWithZero() {
        XCTAssertEqual(model.phase, .amount)
        XCTAssertEqual(model.amount, .zero)
        XCTAssertEqual(model.editingField, .units)
    }

    func testZeroAmountCannotContinue() {
        // È il registro a dire che zero non va bene: la macchina a stati non
        // duplica quella regola, la chiede.
        ledger.validationMessage = "Inserisci un importo"
        XCTAssertFalse(model.isAmountValid)

        ledger.validationMessage = nil
        XCTAssertTrue(model.isAmountValid)
    }

    // MARK: - Regolazione dell'importo

    func testStepUpAddsOneEuro() {
        model.step(1)
        XCTAssertEqual(model.amount, Money(units: 1))
    }

    func testStepDownNeverGoesNegative() {
        model.step(-1)
        XCTAssertEqual(model.amount, .zero)
    }

    func testCentsFieldUsesOneCentSteps() {
        model.step(1)                       // 1,00
        model.select(field: .cents)
        model.step(1)                       // 1,01
        XCTAssertEqual(model.amount, Money(cents: 101))
    }

    func testAmountCannotExceedTheLimit() {
        // Salta direttamente al tetto e prova a superarlo.
        for _ in 0..<20 { model.step(1) }
        XCTAssertLessThanOrEqual(model.amount, AppConfiguration.maximumPayment)
    }

    func testAmountDoesNotChangeOutsideTheAmountPhase() {
        model.step(1)
        model.review()
        XCTAssertEqual(model.phase, .confirmation)

        let before = model.amount
        model.step(1)
        XCTAssertEqual(model.amount, before)
    }

    // MARK: - Tasti del volume

    func testHardwarePressMovesTheAmount() {
        model.startListeningToHardware()
        XCTAssertTrue(model.hardwareVolumeAvailable)

        volume.press(.up)
        volume.press(.up)
        volume.press(.down)

        XCTAssertEqual(model.amount, Money(units: 1))
    }

    /// Nel simulatore, o se il meccanismo non parte, l'app deve restare
    /// utilizzabile con i comandi a schermo.
    func testUnavailableHardwareIsReportedInsteadOfCrashing() {
        volume.startError = VolumeButtonError.unsupportedEnvironment
        model.startListeningToHardware()

        XCTAssertFalse(model.hardwareVolumeAvailable)
        XCTAssertEqual(model.volumeIssue, VolumeButtonError.unsupportedEnvironment.message)

        // I comandi a schermo continuano a funzionare.
        model.step(1)
        XCTAssertEqual(model.amount, Money(units: 1))
    }

    func testStoppingReleasesTheHardware() {
        model.startListeningToHardware()
        model.stopListeningToHardware()

        XCTAssertFalse(model.hardwareVolumeAvailable)
        XCTAssertEqual(volume.stopCount, 1)
    }

    // MARK: - Percorso completo

    func testHappyPathReachesCompletedAndCommitsOnce() async {
        model.step(1)
        model.review()
        XCTAssertEqual(model.phase, .confirmation)

        await model.confirm()

        XCTAssertEqual(model.phase, .completed)
        XCTAssertEqual(ledger.committedDrafts.count, 1)
        XCTAssertEqual(ledger.committedDrafts.first?.amount, Money(units: 1))
        XCTAssertNotNil(model.completed)
    }

    func testReviewIsBlockedWhenTheLedgerObjects() {
        ledger.validationMessage = "Saldo non sufficiente"
        model.review()

        XCTAssertEqual(model.phase, .failed("Saldo non sufficiente"))
        XCTAssertTrue(ledger.committedDrafts.isEmpty)
    }

    func testEditAmountGoesBackFromConfirmation() {
        model.step(1)
        model.review()
        model.editAmount()

        XCTAssertEqual(model.phase, .amount)
    }

    // MARK: - Il punto critico: quando si registra

    /// Annullare l'autenticazione riporta al riepilogo **senza** registrare
    /// nulla, e l'importo resta quello di prima.
    func testCancelledAuthorizationCommitsNothingAndKeepsTheAmount() async {
        authorizer.behaviour = .cancel

        model.step(1)
        model.review()
        await model.confirm()

        XCTAssertEqual(model.phase, .confirmation)
        XCTAssertEqual(model.amount, Money(units: 1))
        XCTAssertTrue(ledger.committedDrafts.isEmpty)
    }

    func testFailedAuthorizationShowsTheReasonAndCommitsNothing() async {
        authorizer.behaviour = .fail(.failed("Viso non riconosciuto"))

        model.step(1)
        model.review()
        await model.confirm()

        XCTAssertEqual(model.phase, .failed("Viso non riconosciuto"))
        XCTAssertTrue(ledger.committedDrafts.isEmpty)
    }

    /// Dopo un errore si torna al **riepilogo**, non alla regolazione: la
    /// cifra era giusta, è stata l'autenticazione a non passare.
    func testRecoveryReturnsToConfirmationWithTheSameAmount() async {
        authorizer.behaviour = .fail(.failed("Viso non riconosciuto"))

        model.step(1)
        model.review()
        await model.confirm()
        model.recoverFromFailure()

        XCTAssertEqual(model.phase, .confirmation)
        XCTAssertEqual(model.amount, Money(units: 1))
    }

    func testLedgerRefusalAtCommitSurfacesTheMessage() async {
        ledger.commitResult = .failure(.insufficientFunds(
            available: .zero,
            requested: Money(units: 1)
        ))

        model.step(1)
        model.review()
        await model.confirm()

        guard case .failed(let message) = model.phase else {
            return XCTFail("Doveva fallire, invece: \(model.phase)")
        }
        XCTAssertTrue(message.contains("Saldo non sufficiente"))
    }

    func testConfirmDoesNothingOutsideConfirmation() async {
        await model.confirm()

        XCTAssertEqual(model.phase, .amount)
        XCTAssertEqual(authorizer.authorizeCallCount, 0)
        XCTAssertTrue(ledger.committedDrafts.isEmpty)
    }

    func testAuthorizationIsRequestedExactlyOnce() async {
        model.step(1)
        model.review()
        await model.confirm()

        XCTAssertEqual(authorizer.authorizeCallCount, 1)
    }

    // MARK: - La bozza

    func testSerialIsStableThroughoutTheFlow() async {
        model.step(1)
        let serial = model.draft.serial

        model.review()
        await model.confirm()

        XCTAssertEqual(model.draft.serial, serial)
        XCTAssertEqual(ledger.committedDrafts.first?.serial, serial)
        XCTAssertTrue(SerialGenerator.isWellFormed(serial))
    }

    func testDraftBecomesATransactionWithTheFrozenName() {
        let draft = PaymentDraft(
            recipient: .fixture(given: "Natalie", family: "Rossi"),
            amount: Money(units: 20)
        )
        let transaction = draft.makeTransaction()

        XCTAssertEqual(transaction.counterpartName, "Natalie Rossi")
        XCTAssertEqual(transaction.direction, .sent)
        XCTAssertEqual(transaction.amount, Money(units: 20))
    }
}
