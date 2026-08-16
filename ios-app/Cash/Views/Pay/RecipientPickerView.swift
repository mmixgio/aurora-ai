import SwiftUI
import UIKit

/// La scelta del destinatario, letto dalla rubrica vera dell'iPhone.
struct RecipientPickerView: View {

    @ObservedObject var service: ContactsService
    let onCancel: () -> Void

    @EnvironmentObject private var appState: AppState
    @State private var query = ""

    var body: some View {
        Group {
            switch service.access {
            case .granted:
                contactList
            case .notDetermined:
                permissionPrompt
            case .denied:
                deniedState
            case .restricted:
                restrictedState
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
        .task {
            // Se il permesso c'è già dalla volta scorsa, la lista si popola
            // da sola senza chiedere di nuovo niente.
            if service.access == .granted {
                await service.load()
            }
        }
    }

    // MARK: - Lista

    private var contactList: some View {
        List {
            if !recents.isEmpty && query.isEmpty {
                Section {
                    ForEach(recents, id: \.id) { contact in
                        contactRow(contact)
                    }
                } header: {
                    sectionHeader("Recenti")
                }
                .listRowBackground(Color.white.opacity(0.03))
            }

            Section {
                if service.isLoading && service.contacts.isEmpty {
                    HStack {
                        ProgressView().tint(Theme.secondaryText)
                        Text("Carico la rubrica…")
                            .font(Theme.body)
                            .foregroundStyle(Theme.secondaryText)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                } else if filteredContacts.isEmpty {
                    Text(query.isEmpty ? "Nessun contatto in rubrica" : "Nessun risultato")
                        .font(Theme.body)
                        .foregroundStyle(Theme.secondaryText)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredContacts, id: \.id) { contact in
                        contactRow(contact)
                    }
                }
            } header: {
                if !service.contacts.isEmpty {
                    sectionHeader(query.isEmpty ? "Tutti i contatti" : "Risultati")
                }
            }
            .listRowBackground(Color.white.opacity(0.03))
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .searchable(text: $query, prompt: "Cerca")
    }

    private func contactRow(_ contact: Contact) -> some View {
        NavigationLink(value: contact) {
            HStack(spacing: 12) {
                AvatarView(contact: contact, size: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    if !contact.organizationName.isEmpty {
                        Text(contact.organizationName)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Theme.tertiaryText)
    }

    private var filteredContacts: [Contact] {
        service.filtered(by: query)
    }

    /// Le persone a cui hai già mandato denaro, riportate in cima.
    /// Il confronto è sul nome completo perché lo storico salva quello.
    private var recents: [Contact] {
        let names = Set(appState.recentCounterparts())
        guard !names.isEmpty else { return [] }
        return service.contacts.filter { names.contains($0.fullName) }
    }

    // MARK: - Stati del permesso

    private var permissionPrompt: some View {
        PermissionCard(
            icon: "person.2",
            title: "Serve la tua rubrica",
            message: "Per scegliere a chi mandare denaro l'app deve leggere i contatti. Restano sul telefono e non vengono salvati da nessuna parte.",
            actionTitle: "Consenti accesso"
        ) {
            Task { await service.requestAccessAndLoad() }
        }
    }

    private var deniedState: some View {
        PermissionCard(
            icon: "lock",
            title: "Accesso ai contatti negato",
            message: "Puoi riattivarlo da Impostazioni › Cash › Contatti.",
            actionTitle: "Apri Impostazioni"
        ) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private var restrictedState: some View {
        PermissionCard(
            icon: "exclamationmark.triangle",
            title: "Accesso non consentito",
            message: "Le restrizioni di sistema impediscono a questa app di leggere i contatti.",
            actionTitle: nil,
            action: nil
        )
    }
}

/// Il riquadro usato per tutti gli stati in cui manca un permesso.
struct PermissionCard: View {

    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.secondaryText)

            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.center)

            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
            }
        }
        .padding(28)
        .frame(maxWidth: 380)
        .padding(.horizontal, Theme.screenPadding)
    }
}
