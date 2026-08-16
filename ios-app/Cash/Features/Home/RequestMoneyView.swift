import SwiftUI

/// Denaro in entrata.
///
/// Usa lo stesso identico meccanismo dell'importo in uscita — tasti del
/// volume, tocco sui centesimi — perché imparare due modi diversi di scrivere
/// una cifra dentro la stessa app non ha senso. Qui però il denaro arriva,
/// quindi niente autenticazione e niente conferma in due tempi.
struct RequestMoneyView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model = RequestMoneyViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                AmountView(
                    amount: model.amount,
                    field: $model.field,
                    onStep: model.step,
                    size: 66
                )
                .padding(.top, 12)

                VolumeControl(
                    onStep: model.step,
                    hardwareAvailable: model.hardwareVolumeAvailable,
                    field: model.field
                )

                BanknoteView(amount: model.amount, signature: appState.signature, width: 250)

                FieldBox(title: "Da") {
                    TextField("Nome", text: $model.senderName)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, Theme.screenPadding)

                Spacer(minLength: 0)

                Button(action: confirm) {
                    Text("Aggiungi al saldo").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: model.canConfirm))
                .disabled(!model.canConfirm)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cashBackground(showsStars: false)
            .navigationTitle("Richiedi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annulla") { dismiss() }
                        .foregroundStyle(Theme.secondaryText)
                }
            }
        }
        .onAppear { model.startListeningToHardware() }
        .onDisappear { model.stopListeningToHardware() }
    }

    private func confirm() {
        switch appState.receive(from: model.trimmedSender, amount: model.amount) {
        case .success:
            Haptics.success()
            dismiss()
        case .failure(let error):
            appState.alert = AppAlert(title: "Movimento non registrato", message: error.message)
        }
    }
}
