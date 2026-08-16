import Contacts
import Foundation

/// Legge la rubrica vera dell'iPhone.
///
/// I contatti non vengono copiati né salvati da nessuna parte: restano in
/// memoria finché l'app è aperta e spariscono quando la chiudi.
@MainActor
final class ContactsService: ObservableObject {

    /// Lo stato del permesso, per capire cosa mostrare a schermo.
    enum Access {
        /// Non abbiamo ancora chiesto niente.
        case notDetermined
        /// L'utente ha detto sì (anche solo per una parte dei contatti).
        case granted
        /// L'utente ha detto no: da qui si può solo mandarlo in Impostazioni.
        case denied
        /// Bloccato da restrizioni di sistema (es. Tempo di utilizzo).
        case restricted
    }

    @Published private(set) var contacts: [Contact] = []
    @Published private(set) var access: Access = .notDetermined
    @Published private(set) var isLoading = false

    private let store = CNContactStore()

    init() {
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            access = .notDetermined
        case .restricted:
            access = .restricted
        case .denied:
            access = .denied
        case .authorized:
            access = .granted
        @unknown default:
            // iOS 18 ha aggiunto l'accesso limitato: da lì in poi qualsiasi
            // stato nuovo che non sia un rifiuto esplicito vale come concesso,
            // tanto la lettura poi restituirà solo ciò a cui abbiamo diritto.
            access = .granted
        }
    }

    /// Chiede il permesso e, se arriva, carica la rubrica.
    func requestAccessAndLoad() async {
        refreshAuthorizationStatus()

        if access == .denied || access == .restricted {
            return
        }

        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }

        access = granted ? .granted : .denied
        guard granted else { return }

        await load()
    }

    /// Carica i contatti fuori dal thread principale: su una rubrica da
    /// qualche migliaio di nomi la lettura non è istantanea e bloccherebbe
    /// visibilmente l'interfaccia.
    func load() async {
        guard access == .granted, !isLoading else { return }
        isLoading = true

        let loaded = await Task.detached(priority: .userInitiated) { () -> [Contact] in
            ContactsService.fetchContacts()
        }.value

        contacts = loaded
        isLoading = false
    }

    private nonisolated static func fetchContacts() -> [Contact] {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.sortOrder = .givenName
        request.unifyResults = true

        var result: [Contact] = []
        let store = CNContactStore()

        do {
            try store.enumerateContacts(with: request) { cnContact, _ in
                let contact = Contact(
                    id: cnContact.identifier,
                    givenName: cnContact.givenName,
                    familyName: cnContact.familyName,
                    organizationName: cnContact.organizationName,
                    imageData: cnContact.thumbnailImageData
                )

                // Le schede completamente vuote (capitano, per importazioni
                // sbagliate) non hanno niente da mostrare in una lista.
                if !contact.givenName.isEmpty
                    || !contact.familyName.isEmpty
                    || !contact.organizationName.isEmpty {
                    result.append(contact)
                }
            }
        } catch {
            return []
        }

        return result.sorted {
            $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
        }
    }

    /// Filtra la lista mentre si scrive nel campo di ricerca.
    func filtered(by query: String) -> [Contact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return contacts }

        return contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(trimmed)
                || $0.organizationName.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
