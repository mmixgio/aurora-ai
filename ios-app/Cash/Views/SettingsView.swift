import SwiftUI

/// Impostazioni: la firma sulla banconota, il conto collegato, l'azzeramento.
struct SettingsView: View {

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var handleDraft = ""
    @State private var showsResetConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    BanknoteView(
                        amount: Money(units: 20),
                        handle: handlePreview,
                        width: 260
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("@NOME", text: $handleDraft)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, design: .monospaced))
                        .onSubmit(saveHandle)
                } header: {
                    Text("Firma sulla banconota")
                } footer: {
                    Text("È il nome stampato in basso a sinistra. Nel video di riferimento è @BENGIANNIS.")
                }

                Section {
                    if let account = appState.account {
                        LabeledContent("Intestatario", value: account.holderName)
                        LabeledContent("IBAN", value: account.maskedIBAN)
                        LabeledContent("Collegato il", value: account.linkedAt.formatted(date: .abbreviated, time: .omitted))
                    } else {
                        Text("Nessun conto collegato")
                            .foregroundStyle(Theme.secondaryText)
                    }
                } header: {
                    Text("Conto")
                } footer: {
                    Text("Le coordinate sono nel Portachiavi dell'iPhone. L'app tiene i movimenti in locale e non è collegata a un circuito bancario: nessun denaro si sposta davvero.")
                }

                Section {
                    LabeledContent("Autenticazione", value: BiometricService.availableBiometry().label)
                    LabeledContent("Gesto di pagamento", value: "Doppio tocco")
                } header: {
                    Text("Sicurezza")
                } footer: {
                    Text("Il doppio clic del tasto laterale è riservato da Apple ad Apple Pay e nessuna app di terze parti può intercettarlo. Il doppio tocco sullo schermo è il gesto più vicino possibile.")
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
                        saveHandle()
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
        .preferredColorScheme(.dark)
        .onAppear { handleDraft = appState.handle }
    }

    /// Quello che si vedrà stampato: la @ viene aggiunta da sola e il campo
    /// vuoto mostra comunque qualcosa, così l'anteprima non resta monca.
    private var handlePreview: String {
        let trimmed = handleDraft.trimmingCharacters(in: .whitespaces).uppercased()
        if trimmed.isEmpty { return "@ME" }
        return trimmed.hasPrefix("@") ? trimmed : "@" + trimmed
    }

    private func saveHandle() {
        appState.handle = handlePreview
        handleDraft = handlePreview
    }
}
