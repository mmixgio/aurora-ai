import Foundation

/// La rubrica per la schermata di scelta del destinatario.
///
/// La vista non conosce il framework Contacts: chiede qui, e qui si parla con
/// un `ContactsProviding` che nei test è un elenco finto.
@MainActor
final class RecipientPickerViewModel: ObservableObject {

    @Published private(set) var access: ContactsAccess = .notDetermined
    @Published private(set) var contacts: [ContactPerson] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var query = ""

    private let service: ContactsProviding

    init(service: ContactsProviding = SystemContactsService()) {
        self.service = service
        self.access = service.authorizationStatus()
    }

    /// Carica se il permesso c'è già, senza richiederlo di nuovo.
    func loadIfPermitted() async {
        access = service.authorizationStatus()
        guard access.canRead else { return }
        await load()
    }

    func requestAccessAndLoad() async {
        access = await service.requestAccess()
        guard access.canRead else { return }
        await load()
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            contacts = try await service.fetchContacts()
            errorMessage = nil
        } catch let error as ContactsError {
            contacts = []
            errorMessage = error.message
        } catch {
            contacts = []
            errorMessage = "Impossibile leggere la rubrica"
        }
    }

    var filteredContacts: [ContactPerson] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return contacts }

        return contacts.filter {
            $0.fullName.localizedCaseInsensitiveContains(trimmed)
                || $0.organizationName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    /// I destinatari recenti, ricavati dallo storico e non da una lista a
    /// parte: il confronto è sul nome completo, che è ciò che i movimenti
    /// congelano.
    func recents(matching names: [String]) -> [ContactPerson] {
        guard query.isEmpty, !names.isEmpty else { return [] }
        let wanted = Set(names)
        return contacts.filter { wanted.contains($0.fullName) }
    }
}
