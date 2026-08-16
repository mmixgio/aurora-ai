import Foundation

/// Le fasi del pagamento.
///
/// ```
/// amount  →  confirmation  →  authentication  →  sending  →  completed
///                  ↑________________|
///                        failed
/// ```
///
/// Non sono cinque schermate: sono cinque stati di **una** schermata, dentro
/// la quale la banconota è sempre lo stesso oggetto che cambia posizione,
/// scala, rotazione e opacità. È l'unico modo perché quel movimento sia
/// continuo invece di una sequenza di comparse e sparizioni.
enum PaymentPhase: Equatable, Sendable {

    /// Si regola quanto inviare.
    case amount

    /// Riepilogo, in attesa della conferma esplicita.
    case confirmation

    /// Autenticazione in corso: Face ID di sistema o pannello Apple Pay.
    case authentication

    /// La banconota vola verso l'avatar. Il movimento è già partito ma il
    /// movimento contabile **non è ancora stato registrato**.
    case sending

    /// Concluso e salvato su disco.
    case completed

    /// Qualcosa si è fermato: il messaggio è quello da mostrare.
    case failed(String)

    /// Vero quando i tasti del volume devono essere ascoltati.
    var acceptsAmountInput: Bool { self == .amount }

    /// Vero quando la banconota deve essere visibile in campo.
    var showsBanknote: Bool {
        self == .authentication || self == .sending
    }

    var isTerminal: Bool { self == .completed }
}
