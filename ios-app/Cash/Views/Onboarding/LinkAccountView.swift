import SwiftUI

/// Il collegamento del conto bancario.
///
/// L'IBAN viene validato davvero (lunghezza per paese e cifra di controllo
/// modulo 97) e salvato nel Portachiavi. Va detto chiaramente: registrare le
/// coordinate qui **non muove denaro vero** — per farlo servirebbe un
/// istituto di pagamento autorizzato dietro all'app.
struct LinkAccountView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var holderName = ""
    @State private var ibanInput = ""
    @FocusState private var focusedField: Field?

    private enum Field {
        case holder
        case iban
    }

    private var validation: IBAN.ValidationResult {
        IBAN.validate(ibanInput)
    }

    /// L'errore si mostra solo quando ha senso mostrarlo: mentre stai ancora
    /// scrivendo l'IBAN è ovviamente incompleto, dirtelo a ogni tasto sarebbe
    /// solo rumore rosso sotto il campo.
    private var visibleError: String? {
        guard !ibanInput.isEmpty, focusedField != .iban else { return nil }
        return validation.message
    }

    private var canSubmit: Bool {
        validation.isValid && !holderName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(spacing: 18) {
                    FieldBox(title: "Intestatario") {
                        TextField("Nome e cognome", text: $holderName)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .holder)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .iban }
                    }

                    FieldBox(title: "IBAN", error: visibleError) {
                        TextField("IT60 X054 2811 1010 0000 0123 456", text: $ibanInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .keyboardType(.asciiCapable)
                            .font(.system(size: 17, weight: .regular, design: .monospaced))
                            .focused($focusedField, equals: .iban)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                            .onChange(of: ibanInput) { _, newValue in
                                // Riformatta mentre scrivi. La funzione è
                                // idempotente, quindi riassegnare il valore
                                // non innesca un ciclo infinito.
                                let formatted = IBAN.formatted(newValue)
                                if formatted != newValue { ibanInput = formatted }
                            }
                    }

                    if validation.isValid {
                        Label("IBAN valido", systemImage: "checkmark.circle.fill")
                            .font(Theme.caption)
                            .foregroundStyle(Theme.faceID)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .transition(.opacity)
                    }
                }
                .animation(Motion.detail, value: validation)

                disclaimer

                Spacer(minLength: 20)

                Button {
                    link()
                } label: {
                    Text("Collega conto")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(isEnabled: canSubmit))
                .disabled(!canSubmit)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Da dove partono i pagamenti")
                .font(Theme.title)
                .foregroundStyle(Theme.primaryText)

            Text("Serve una sola volta. Puoi cambiarlo quando vuoi dalle impostazioni.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 14))
                .foregroundStyle(Theme.tertiaryText)

            Text("Questa app registra le coordinate e tiene il conto dei movimenti sul telefono. Non è collegata a un circuito bancario, quindi nessun denaro si sposta davvero.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.tertiaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func link() {
        guard canSubmit else { return }

        let account = BankAccount(
            holderName: holderName,
            iban: ibanInput,
            bankName: ""
        )

        appState.link(account: account)

        // La firma sulla banconota parte dal nome dell'intestatario, così la
        // prima banconota che vedi ha già il tuo nome sopra.
        if appState.handle == "@ME", let first = holderName.split(separator: " ").first {
            appState.handle = "@" + first.uppercased()
        }

        Haptics.success()
        dismiss()
    }
}

/// Un campo di testo incorniciato, in tinta con il resto dell'app.
struct FieldBox<Content: View>: View {

    let title: String
    var error: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.tertiaryText)

            content
                .font(.system(size: 17))
                .foregroundStyle(Theme.primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            error == nil ? Theme.hairline : Theme.destructive.opacity(0.65),
                            lineWidth: 1
                        )
                )

            if let error {
                Text(error)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.destructive)
                    .transition(.opacity)
            }
        }
    }
}
