import Foundation

/// L'accelerazione dell'importo quando si tiene premuto un tasto del volume.
///
/// Tenendo premuto, iOS ripete la pressione in fretta: da un certo punto in
/// poi il passo cresce, altrimenti arrivare a 200 € vorrebbe dire premere
/// duecento volte. Rallentando, o cambiando verso, si torna subito al passo
/// da uno per aggiustare al centesimo.
///
/// È un valore puro, senza timer e senza stato globale: il tempo entra come
/// parametro, quindi i test possono simulare una raffica senza aspettarla.
struct StepAccelerator: Equatable {

    /// Quante pressioni consecutive sono state contate finora.
    private(set) var streak = 0

    private var lastPressAt: Date?
    private var lastDirection = 0

    /// Oltre questo intervallo fra due pressioni la raffica è considerata finita.
    let burstWindow: TimeInterval

    init(burstWindow: TimeInterval = AppConfiguration.stepBurstWindow) {
        self.burstWindow = burstWindow
    }

    /// Registra una pressione e restituisce di quanto moltiplicare il passo.
    mutating func multiplier(for direction: Int, at now: Date = Date()) -> Int64 {
        let withinBurst = lastPressAt.map { now.timeIntervalSince($0) < burstWindow } ?? false
        streak = (withinBurst && direction == lastDirection) ? streak + 1 : 0

        lastPressAt = now
        lastDirection = direction

        return StepAccelerator.multiplier(forStreak: streak)
    }

    /// La curva dell'accelerazione. Statica perché è una tabella, non uno stato.
    static func multiplier(forStreak streak: Int) -> Int64 {
        switch streak {
        case ..<0:   return 1
        case 0...2:  return 1
        case 3...6:  return 2
        case 7...12: return 5
        default:     return AppConfiguration.maximumStepMultiplier
        }
    }

    /// Azzera la raffica. Da chiamare quando si passa da euro a centesimi:
    /// il primo tocco sui centesimi non deve ereditare la velocità accumulata.
    mutating func reset() {
        streak = 0
        lastPressAt = nil
        lastDirection = 0
    }
}
