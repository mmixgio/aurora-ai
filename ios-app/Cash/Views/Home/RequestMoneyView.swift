import SwiftUI

/// Denaro in entrata.
///
/// È la controparte del pagamento e riusa la stessa banconota: qui però
/// l'importo arriva invece di partire, quindi niente Face ID e niente gesto.
struct RequestMoneyView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var senderName = ""
    @State private var digits = ""

    private var amount: Money {
        Money(cents: Int(digits) ?? 0)
    }

    private var canConfirm: Bool {
        !amount.isZero && !senderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text(amount.formatted())
                    .font(Theme.amount(64))
                    .foregroundStyle(amount.isZero ? Theme.tertiaryText : Theme.primaryText)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.25), value: amount)
                    .padding(.top, 20)

                BanknoteView(amount: amount, handle: appState.handle, width: 260)

                FieldBox(title: "Da") {
                    TextField("Nome", text: $senderName)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, Theme.screenPadding)

                Spacer(minLength: 0)

                KeypadView(
                    onDigit: { digit in
                        guard digits.count < AppConfiguration.maximumDigits else { return }
                        if digits.isEmpty && digit == 0 { return }
                        digits.append(String(digit))
                        Haptics.tap()
                    },
                    onDelete: {
                        guard !digits.isEmpty else { return }
                        digits.removeLast()
                        Haptics.tap()
                    }
                )
                .padding(.horizontal, 40)

                Button {
                    appState.receive(from: senderName, amount: amount)
                    Haptics.success()
                    dismiss()
                } label: {
                    Text("Aggiungi al saldo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canConfirm))
                .disabled(!canConfirm)
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 12)
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
    }
}
