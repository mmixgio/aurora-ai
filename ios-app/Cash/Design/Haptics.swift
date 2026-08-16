import UIKit

/// Il feedback tattile. In un'app di pagamento la vibrazione non è un vezzo:
/// è la conferma fisica che qualcosa è successo, e nel video ogni passaggio
/// ne ha una diversa.
enum Haptics {

    /// Tocco secco sui tasti del tastierino.
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// Il "click" del gesto di pagamento: più corposo, si deve sentire.
    static func arm() {
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

    /// Da chiamare poco prima di una vibrazione importante: sveglia il motore
    /// tattile ed elimina il ritardo di qualche decina di millisecondi.
    static func prepare() {
        UIImpactFeedbackGenerator(style: .rigid).prepare()
        UINotificationFeedbackGenerator().prepare()
    }
}
