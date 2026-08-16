import SwiftUI

/// Contiene l'intera sequenza: scegli la persona, poi paghi.
///
/// Vive a schermo intero perché da qui in poi non deve esserci nient'altro:
/// né barre, né bordi della home che si intravedono.
struct PaymentFlowView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.paymentPath) {
            RecipientPickerView(onCancel: router.finishPayment)
                .navigationDestination(for: ContactPerson.self) { recipient in
                    PaymentView(
                        recipient: recipient,
                        ledger: appState,
                        onFinish: router.finishPayment
                    )
                }
        }
        .tint(.white)
    }
}
