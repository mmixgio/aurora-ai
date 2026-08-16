import Foundation
import SwiftUI

/// La logica del denaro in entrata.
@MainActor
final class RequestMoneyViewModel: ObservableObject {

    @Published private(set) var amount: Money = .zero
    @Published var field: AmountField = .units {
        didSet {
            // Il primo tocco sui centesimi non deve ereditare la velocità
            // accumulata regolando gli euro.
            if field != oldValue { accelerator.reset() }
        }
    }
    @Published var senderName = ""
    @Published private(set) var hardwareVolumeAvailable = false

    private let volume: HardwareVolumeObserving
    private var accelerator = StepAccelerator()

    init(volume: HardwareVolumeObserving = VolumeButtonService()) {
        self.volume = volume
    }

    var trimmedSender: String {
        senderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canConfirm: Bool {
        !amount.isZero && !trimmedSender.isEmpty
    }

    func step(_ direction: Int) {
        guard direction != 0 else { return }

        let multiplier = accelerator.multiplier(for: direction, at: Date())
        let delta = Int64(direction) * field.stepInCents * multiplier
        let next = amount.stepped(by: delta, clampedTo: AppConfiguration.amountRange)

        guard next != amount else { return }
        withAnimation(Motion.value) { amount = next }
        Haptics.step()
    }

    func startListeningToHardware() {
        do {
            try volume.start { [weak self] direction in
                self?.step(direction == .up ? 1 : -1)
            }
            hardwareVolumeAvailable = volume.isListening
        } catch {
            hardwareVolumeAvailable = false
        }
    }

    func stopListeningToHardware() {
        volume.stop()
        hardwareVolumeAvailable = false
    }
}
