import SwiftUI

/// Le curve di animazione dell'app, tutte in un posto solo.
///
/// Il movimento qui non è decorazione: è quello che fa sembrare la banconota
/// un oggetto con un peso invece di un rettangolo che si teletrasporta. Per
/// questo sono **molle e non durate fisse** — una molla decelera come farebbe
/// una cosa vera, una curva `easeOut` no.
///
/// `response` è quanto impiega a coprire la distanza, `dampingFraction`
/// quanto rimbalza alla fine: sotto 1 rimbalza, a 1 si ferma netto.
enum Motion {

    /// Il passaggio da una fase all'altra del pagamento.
    static let phase = Animation.spring(response: 0.60, dampingFraction: 0.86)

    /// La banconota che entra in campo durante l'autenticazione. Lenta e
    /// pesante: deve sembrare che entri, non che appaia.
    static let noteRise = Animation.spring(response: 0.95, dampingFraction: 0.84)

    /// La banconota assorbita dall'avatar. Parte decisa e frena dolcemente,
    /// **senza rimbalzo**: un rimbalzo nel momento in cui il denaro sparisce
    /// sembrerebbe un errore.
    static let noteFly = Animation.spring(response: 0.80, dampingFraction: 0.95)

    /// L'importo che cambia sotto i tasti del volume. Corta, o si accumula
    /// ritardo quando si tiene premuto.
    static let value = Animation.spring(response: 0.28, dampingFraction: 0.80)

    /// Dettagli: sottolineature, avvisi, comparse minori.
    static let detail = Animation.spring(response: 0.38, dampingFraction: 0.88)

    /// La pressione di un pulsante.
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.70)

    /// Il ritorno dopo un errore: più lento, per dare il tempo di leggere.
    static let recover = Animation.spring(response: 0.70, dampingFraction: 0.90)

    // MARK: - Tempi della sequenza
    //
    // Numeri che contano per l'esperienza, quindi non sparsi nelle viste.

    /// Attesa fra la comparsa dell'anello e l'apertura dell'autenticazione di
    /// sistema: senza, il pannello di iOS coprirebbe l'anello sul nascere.
    static let authenticationLeadIn: Duration = .milliseconds(260)

    /// Durata del volo della banconota, prima che il movimento venga
    /// registrato in contabilità.
    static let sendingFlight: Duration = .milliseconds(950)

    /// Quanto resta a schermo la conferma prima di chiudere da sola.
    static let completionHold: Duration = .milliseconds(2200)
}

extension AnyTransition {

    /// L'entrata e l'uscita di una fase.
    ///
    /// Asimmetrica di proposito: ciò che entra cresce di un soffio da sotto la
    /// propria dimensione, ciò che esce si allarga appena mentre svanisce.
    /// Così lo sguardo segue il contenuto nuovo invece di vedere due cose
    /// accavallarsi.
    static var phaseChange: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .scale(scale: 1.03))
        )
    }

    static var riseUp: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        )
    }
}
