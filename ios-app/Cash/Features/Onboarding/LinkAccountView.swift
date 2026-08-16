import SwiftUI

/// Il collegamento del conto.
///
/// L'IBAN viene validato secondo lo standard e salvato nel Portachiavi.
/// Registrarlo qui **non muove denaro**: la contabilità è locale e l'app non
/// è collegata ad alcun circuito bancario.
struct LinkAccountView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model = LinkAccountViewModel()
    @FocusState private var focusedField: Field?

    private enum Field {
        case holder
        case iban
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(spacing: 18) {
                    FieldBox(title: "Intestatario") {
                        TextField("Nome e cognome", text: $model.holderName)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .holder)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .iban }
                    }

                    FieldBox(title: "IBAN", error: model.visibleError) {
                        TextField("IT60 X054 2811 1010 0000 0123 456", text: $model.ibanInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .iban)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                            .accessibilityLabel("IBAN")
                    }

                    if model.isIBANValid {
                        Label("IBAN valido", systemImage: "checkmark.circle.fill")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.positive)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.riseUp)
                    }
                }
                .animation(Motion.detail, value: model.ibanInput)
                .animation(Motion.detail, value: model.isEditingIBAN)

                disclaimer

                Spacer(minLength: 20)

                Button(action: link) {
                    Text("Collega conto").frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: model.canSubmit))
                .disabled(!model.canSubmit)
            }
            .padding(.horizontal, Theme.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cashBackground(showsStars: false)
        .navigationTitle("Il tuo conto")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .onChange(of: focusedField) { _, field in
            model.isEditingIBAN = (field == .iban)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Da dove partono i pagamenti")
                .font(Theme.title)
                .foregroundStyle(Theme.primaryText)

            Text("Serve una sola volta. Puoi cambiarlo quando vuoi dal profilo.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(Theme.caption)
                .foregroundStyle(Theme.tertiaryText)
                .accessibilityHidden(true)

            Text("L'app registra le coordinate e tiene i movimenti sul telefono. Non è collegata a un circuito bancario, quindi nessun denaro si sposta davvero.")
                .font(Theme.micro)
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.surface)
        )
    }

    private func link() {
        guard let account = model.makeAccount() else { return }
        appState.link(account: account)
        Haptics.success()
        dismiss()
    }
}
