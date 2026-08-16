import XCTest
@testable import Cash

/// L'accelerazione dell'importo tenendo premuto il tasto del volume.
final class StepAcceleratorTests: XCTestCase {

    private let start = Date(timeIntervalSinceReferenceDate: 0)

    /// La tabella richiesta: 1-3 pressioni ×1, 4-7 ×2, 8-13 ×5, oltre ×10.
    /// Lo `streak` parte da 0, quindi la prima pressione è streak 0.
    func testMultiplierTable() {
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 0), 1)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 2), 1)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 3), 2)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 6), 2)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 7), 5)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 12), 5)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 13), 10)
        XCTAssertEqual(StepAccelerator.multiplier(forStreak: 500), 10)
    }

    func testBurstRampsUp() {
        var accelerator = StepAccelerator()
        var multipliers: [Int64] = []

        for index in 0..<14 {
            let moment = start.addingTimeInterval(Double(index) * 0.1)
            multipliers.append(accelerator.multiplier(for: 1, at: moment))
        }

        XCTAssertEqual(Array(multipliers.prefix(3)), [1, 1, 1])
        XCTAssertEqual(Array(multipliers[3...6]), [2, 2, 2, 2])
        XCTAssertEqual(Array(multipliers[7...12]), [5, 5, 5, 5, 5, 5])
        XCTAssertEqual(multipliers[13], 10)
    }

    /// Rallentando oltre la finestra la raffica finisce e si torna al passo
    /// da uno: serve ad aggiustare al centesimo dopo aver corso.
    func testPauseResetsTheBurst() {
        var accelerator = StepAccelerator()

        for index in 0..<10 {
            _ = accelerator.multiplier(for: 1, at: start.addingTimeInterval(Double(index) * 0.1))
        }
        XCTAssertEqual(accelerator.streak, 9)

        let afterPause = accelerator.multiplier(for: 1, at: start.addingTimeInterval(5))
        XCTAssertEqual(afterPause, 1)
        XCTAssertEqual(accelerator.streak, 0)
    }

    func testChangingDirectionResetsTheBurst() {
        var accelerator = StepAccelerator()

        for index in 0..<10 {
            _ = accelerator.multiplier(for: 1, at: start.addingTimeInterval(Double(index) * 0.1))
        }

        let reversed = accelerator.multiplier(for: -1, at: start.addingTimeInterval(1.0))
        XCTAssertEqual(reversed, 1)
        XCTAssertEqual(accelerator.streak, 0)
    }

    func testExplicitResetClearsEverything() {
        var accelerator = StepAccelerator()
        for index in 0..<10 {
            _ = accelerator.multiplier(for: 1, at: start.addingTimeInterval(Double(index) * 0.1))
        }

        accelerator.reset()
        XCTAssertEqual(accelerator.streak, 0)
        XCTAssertEqual(accelerator.multiplier(for: 1, at: start.addingTimeInterval(1.05)), 1)
    }

    /// Esattamente sul confine la raffica è considerata finita: la finestra è
    /// aperta a sinistra e chiusa a destra.
    func testBurstWindowBoundary() {
        var accelerator = StepAccelerator(burstWindow: 0.45)

        _ = accelerator.multiplier(for: 1, at: start)
        _ = accelerator.multiplier(for: 1, at: start.addingTimeInterval(0.44))
        XCTAssertEqual(accelerator.streak, 1)

        _ = accelerator.multiplier(for: 1, at: start.addingTimeInterval(0.44 + 0.45))
        XCTAssertEqual(accelerator.streak, 0)
    }
}
