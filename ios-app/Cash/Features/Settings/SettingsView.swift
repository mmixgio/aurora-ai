import SwiftUI

/// Profilo: la firma sulla banconota, il conto collegato, l'azzeramento.
struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @StateObject private var model = SettingsViewModel()
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BanknoteView(
                        amount: Money(units: 20),
                        signature: model.signaturePreview,
                        width: 260
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("@NOME", text: $model.signatureDraft)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .accessibilityLabel("Firma sulla banconota")
                } header: {
                    Text("Firma sulla banconota")
                } footer: {
                    Text("È il nome stampato in basso a sinistra. La chiocciola viene aggiunta da sola.")
                }

                Section {
                    if let account = appState.account {
                        LabeledContent("Intestatario", value: account.holderName)
                        LabeledContent("IBAN", value: account.maskedIBAN)
                        LabeledContent(
                            "Collegato il",
                            value: account.linkedAt.formatted(date: .abbreviated, time: .omitted)
                        )
                    } else {
                        Text("Nessun conto collegato")
                            .foregroundStyle(Theme.secondaryText)
                    }
                } header: {
                    Text("Conto")
                } footer: {
                    Text("Le coordinate sono nel Portachiavi, protette e non incluse nei backup verso altri dispositivi. L'app tiene i movimenti in locale e non è collegata a un circuito bancario: nessun denaro si sposta davvero.")
                }

                Section {
                    LabeledContent("Autenticazione", value: model.authenticationLabel)
                    LabeledContent("Conferma", value: model.confirmationLabel)
                    LabeledContent("Rete", value: "Nessuna")
                } header: {
                    Text("Sicurezza e privacy")
                } footer: {
                    Text("L'app non contatta nessun server: niente account, niente analytics, niente pubblicità. Il doppio clic del tasto laterale è riservato da Apple ad Apple Pay e nessuna app di terze parti può intercettarlo.")
                }

                Section {
                    Button(role: .destructive) {
                        showsResetConfirmation = true
                    } label: {
                        Text("Azzera tutto")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Profilo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") {
                        appState.updateSignature(model.signatureDraft)
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Cancellare saldo, storico e conto collegato?",
                isPresented: $showsResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Azzera tutto", role: .destructive) {
                    appState.resetEverything()
                    dismiss()
                }
                Button("Annulla", role: .cancel) {}
            }
        }
        .onAppear { model.load(current: appState.signature) }
    }
}
