import SwiftUI

/// Le curve di animazione dell'app, tutte in un posto solo.
///
/// Il movimento qui non è decorazione: è quello che fa sembrare la banconota
/// un oggetto con un peso invece che un rettangolo che si teletrasporta. Per
/// questo le transizioni sono molle e non durate fisse — una molla decelera
/// come farebbe una cosa vera, una curva `easeOut` no.
///
/// `response` è quanto ci mette a coprire la distanza, `dampingFraction`
/// quanto rimbalza alla fine: sotto 1 rimbalza, a 1 si ferma netto.
enum Motion {

    /// Il passaggio da una fase all'altra del pagamento.
    static let phase = Animation.spring(response: 0.60, dampingFraction: 0.86)

    /// La banconota che sale in campo durante il Face ID. Lenta e pesante:
    /// deve sembrare che entri, non che appaia.
    static let noteRise = Animation.spring(response: 0.95, dampingFraction: 0.84)

    /// La banconota che viene assorbita dall'avatar. Parte decisa e frena
    /// dolcemente, senza rimbalzo: un rimbalzo qui sembrerebbe un errore.
    static let noteFly = Animation.spring(response: 0.80, dampingFraction: 0.95)

    /// L'importo che cambia sotto i tasti del volume. Corta, o si accumula
    /// ritardo quando si tiene premuto.
    static let value = Animation.spring(response: 0.28, dampingFraction: 0.80)

    /// Comparse e sparizioni di dettagli: sottolineature, avvisi, pulsanti.
    static let detail = Animation.spring(response: 0.38, dampingFraction: 0.88)

    /// La pressione di un pulsante.
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.70)

    /// Il ritorno indietro dopo un errore: più lento, per dare il tempo di
    /// leggere cosa è andato storto.
    static let recover = Animation.spring(response: 0.70, dampingFraction: 0.90)
}

extension AnyTransition {

    /// L'entrata e l'uscita di una fase.
    ///
    /// Asimmetrica di proposito: quello che entra cresce di un soffio da
    /// sotto la sua dimensione, quello che esce si allarga appena mentre
    /// svanisce. Il risultato è che lo sguardo segue il nuovo contenuto
    /// invece di vedere due cose accavallarsi.
    static var phaseChange: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.96)),
            removal: .opacity.combined(with: .scale(scale: 1.03))
        )
    }

    /// Per gli elementi che salgono dal basso, come gli avvisi.
    static var riseUp: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)),
            removal: .opacity
        )
    }
}
