import SwiftUI

/// Denaro in entrata.
///
/// È la controparte del pagamento e usa lo stesso identico meccanismo per
/// l'importo — tasti del volume, tocco sui centesimi — perché imparare due
/// modi diversi di scrivere una cifra dentro la stessa app non ha senso.
/// Qui però il denaro arriva, quindi niente Face ID e niente conferma.
struct RequestMoneyView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var volume = VolumeButtonService()

    @State private var senderName = ""
    @State private var amount: Money = .zero
    @State private var field: AmountField = .units

    private var canConfirm: Bool {
        !amount.isZero && !senderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 26) {
                AmountFieldView(
                    amount: amount,
                    field: $field,
                    onStep: step,
                    size: 68,
                    volumeUnavailable: !volume.isListening
                )
                .padding(.top, 16)

                BanknoteView(amount: amount, handle: appState.handle, width: 250)

                FieldBox(title: "Da") {
                    TextField("Nome", text: $senderName)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, Theme.screenPadding)

                Spacer(minLength: 0)

                Button {
                    appState.receive(from: senderName, amount: amount)
                    Haptics.success()
                    dismiss()
                } label: {
                    Text("Aggiungi al saldo").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canConfirm))
                .disabled(!canConfirm)
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
        .preferredColorScheme(.dark)
        .onAppear {
            volume.onPress = { direction in
                step(direction == .up ? 1 : -1)
            }
            volume.start()
        }
        .onDisappear { volume.stop() }
    }

    private func step(_ direction: Int) {
        let delta = direction * field.stepInCents
        let target = min(max(amount.cents + delta, 0), AppConfiguration.maximumPayment.cents)
        guard target != amount.cents else { return }

        withAnimation(Motion.value) {
            amount = Money(cents: target)
        }
        Haptics.tap()
    }
}
