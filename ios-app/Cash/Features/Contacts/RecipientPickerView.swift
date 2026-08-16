import SwiftUI

/// La scelta del destinatario, dalla rubrica vera dell'iPhone.
struct RecipientPickerView: View {

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var router: AppRouter
    @StateObject private var model = RecipientPickerViewModel()

    let onCancel: () -> Void

    var body: some View {
        Group {
            switch model.access {
            case .authorized:    contactList
            case .notDetermined: permissionPrompt
            case .denied:        deniedState
            case .restricted:    restrictedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .cashBackground(showsStars: false)
        .navigationTitle("A chi")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Annulla", action: onCancel)
                    .foregroundStyle(Theme.secondaryText)
            }
        }
        .task { await model.loadIfPermitted() }
    }

    // MARK: - Lista

    private var contactList: some View {
        List {
            let recents = model.recents(matching: appState.recentCounterparts())

            if !recents.isEmpty {
                Section("Recenti") {
                    ForEach(recents) { contact in
                        row(contact)
                    }
                }
                .listRowBackground(Theme.surface)
            }

            Section(model.query.isEmpty ? "Tutti i contatti" : "Risultati") {
                if model.isLoading && model.contacts.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.secondaryText)
                        Text("Carico la rubrica…")
                            .font(Theme.body)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 8)
                } else if let errorMessage = model.errorMessage {
                    Text(errorMessage)
                        .font(Theme.body)
                        .foregroundStyle(Theme.destructive)
                        .padding(.vertical, 8)
                } else if model.filteredContacts.isEmpty {
                    Text(model.query.isEmpty ? "Nessun contatto in rubrica" : "Nessun risultato")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 8)
                } else {
                    ForEach(model.filteredContacts) { contact in
                        row(contact)
                    }
                }
            }
            .listRowBackground(Theme.surface)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $model.query, prompt: "Cerca")
    }

    private func row(_ contact: ContactPerson) -> some View {
        Button {
            router.choose(recipient: contact)
        } label: {
            HStack(spacing: 12) {
                AvatarView(contact: contact, size: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.fullName)
                        .font(Theme.bodyEmphasis)
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    if !contact.organizationName.isEmpty {
                        Text(contact.organizationName)
                            .font(Theme.caption)
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.tertiaryText)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Invia denaro a \(contact.fullName)")
    }

    // MARK: - Stati del permesso

    private var permissionPrompt: some View {
        PermissionStateView(
            icon: "person.2",
            title: "Serve la tua rubrica",
            message: "Per scegliere a chi mandare denaro l'app deve leggere i contatti. Restano sul telefono e non vengono salvati da nessuna parte.",
            actionTitle: "Consenti accesso"
        ) {
            Task { await model.requestAccessAndLoad() }
        }
    }

    private var deniedState: some View {
        PermissionStateView(
            icon: "lock",
            title: "Accesso ai contatti negato",
            message: "Puoi riattivarlo da Impostazioni › Cash › Contatti.",
            actionTitle: "Apri Impostazioni",
            action: SystemSettings.open
        )
    }

    private var restrictedState: some View {
        PermissionStateView(
            icon: "exclamationmark.triangle",
            title: "Accesso non consentito",
            message: "Le restrizioni di sistema impediscono a questa app di leggere i contatti."
        )
    }
}
