import UIKit

/// Il feedback tattile.
///
/// In un'app di pagamento la vibrazione non è un vezzo: è la conferma fisica
/// che qualcosa è successo. Ogni passaggio ne ha una diversa, così la mano
/// distingue uno scatto dell'importo da un pagamento andato a buon fine.
@MainActor
enum Haptics {

    /// Scatto secco dell'importo.
    static func step() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// La conferma del pagamento: più corposa, si deve sentire.
    static func confirm() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 1.0)
    }

    /// La banconota che parte.
    static func send() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.85)
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// Sveglia il motore tattile poco prima di una vibrazione importante,
    /// eliminando le decine di millisecondi di ritardo al primo colpo.
    static func prepare() {
        UIImpactFeedbackGenerator(style: .rigid).prepare()
        UINotificationFeedbackGenerator().prepare()
    }
}
