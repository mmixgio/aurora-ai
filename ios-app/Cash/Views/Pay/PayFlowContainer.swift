import SwiftUI

/// Contiene l'intera sequenza di pagamento: scegli la persona, poi paghi.
///
/// Vive in `fullScreenCover` perché da qui in poi non deve esserci nient'altro
/// a schermo: né barre, né sfondo della home che si intravede dai bordi.
struct PayFlowContainer: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var contactsService = ContactsService()
    @State private var path: [Contact] = []

    var body: some View {
        NavigationStack(path: $path) {
            RecipientPickerView(service: contactsService) {
                dismiss()
            }
            .navigationDestination(for: Contact.self) { contact in
                PaymentView(
                    recipient: contact,
                    appState: appState,
                    onFinish: { dismiss() }
                )
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
    }
}
