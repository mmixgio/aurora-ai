import PassKit
import SwiftUI
import UIKit

/// Il pulsante ufficiale di Apple Pay.
///
/// È `PKPaymentButton` di UIKit portato in SwiftUI, non una copia disegnata a
/// mano: il marchio, il font e le proporzioni devono essere quelli veri, e
/// ridisegnarli sarebbe sia sbagliato sia inutile.
struct ApplePayButton: UIViewRepresentable {

    var type: PKPaymentButtonType = .plain
    var style: PKPaymentButtonStyle = .white
    var cornerRadius: CGFloat = 27

    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> PKPaymentButton {
        let button = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        button.cornerRadius = cornerRadius

        // Senza queste due righe il pulsante si stringe attorno al proprio
        // marchio invece di occupare la larghezza che SwiftUI gli assegna.
        button.setContentHuggingPriority(.defaultLow, for: .horizontal)
        button.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.trigger),
            for: .touchUpInside
        )
        return button
    }

    func updateUIView(_ uiView: PKPaymentButton, context: Context) {
        // La chiusura può cambiare a ogni ridisegno della vista: il
        // coordinatore vive più a lungo, quindi va tenuta aggiornata.
        context.coordinator.action = action
        uiView.cornerRadius = cornerRadius
    }

    final class Coordinator: NSObject {
        var action: () -> Void

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func trigger() {
            action()
        }
    }
}
