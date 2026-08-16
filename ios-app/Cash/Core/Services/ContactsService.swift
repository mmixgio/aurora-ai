import Contacts
import Foundation

/// Lo stato del permesso alla rubrica.
enum ContactsAccess: Equatable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted

    var canRead: Bool { self == .authorized }
}

enum ContactsError: Error, Equatable {
    case accessDenied
    case accessRestricted
    case readFailed(String)

    var message: String {
        switch self {
        case .accessDenied:
            return "Accesso ai contatti negato"
        case .accessRestricted:
            return "Le restrizioni di sistema impediscono l'accesso ai contatti"
        case .readFailed(let reason):
            return "Impossibile leggere la rubrica: \(reason)"
        }
    }
}

/// La rubrica, dietro un protocollo.
///
/// Serve a due cose: tenere il framework Contacts fuori dalle viste, e
/// permettere ai test di girare con un elenco finto senza chiedere permessi.
protocol ContactsProviding: AnyObject, Sendable {
    func authorizationStatus() -> ContactsAccess
    func requestAccess() async -> ContactsAccess
    func fetchContacts() async throws -> [ContactPerson]
}

/// L'implementazione sul framework Contacts.
///
/// I contatti non vengono mai salvati: vivono in memoria finché la sessione
/// è aperta e spariscono con l'app.
final class SystemContactsService: ContactsProviding, @unchecked Sendable {

    private let store = CNContactStore()

    /// Una coda dedicata, non il pool cooperativo di Swift Concurrency.
    ///
    /// `enumerateContacts` è sincrona e su una rubrica grande blocca per
    /// centinaia di millisecondi: lasciata sul pool sottrarrebbe un thread a
    /// tutto il resto delle operazioni asincrone dell'app.
    private let queue = DispatchQueue(label: "com.cash.contacts", qos: .userInitiated)

    private static let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactThumbnailImageDataKey as CNKeyDescriptor
    ]

    func authorizationStatus() -> ContactsAccess {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined: return .notDetermined
        case .restricted:    return .restricted
        case .denied:        return .denied
        case .authorized:    return .authorized
        @unknown default:
            // iOS 18 ha introdotto l'accesso limitato. Qualsiasi stato futuro
            // che non sia un rifiuto esplicito vale come concesso: la lettura
            // restituirà comunque solo ciò a cui abbiamo diritto.
            return .authorized
        }
    }

    func requestAccess() async -> ContactsAccess {
        let current = authorizationStatus()
        guard current == .notDetermined else { return current }

        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }

        return granted ? .authorized : .denied
    }

    func fetchContacts() async throws -> [ContactPerson] {
        switch authorizationStatus() {
        case .denied:     throw ContactsError.accessDenied
        case .restricted: throw ContactsError.accessRestricted
        case .notDetermined, .authorized: break
        }

        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [store] in
                let request = CNContactFetchRequest(keysToFetch: SystemContactsService.keysToFetch)
                request.sortOrder = .givenName
                request.unifyResults = true

                var people: [ContactPerson] = []

                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        let person = ContactPerson(
                            id: contact.identifier,
                            givenName: contact.givenName,
                            familyName: contact.familyName,
                            organizationName: contact.organizationName,
                            imageData: contact.thumbnailImageData
                        )
                        // Le schede completamente vuote — capita con le
                        // importazioni malriuscite — non hanno nulla da
                        // mostrare in una lista.
                        if person.isPresentable { people.append(person) }
                    }
                } catch {
                    continuation.resume(
                        throwing: ContactsError.readFailed(error.localizedDescription)
                    )
                    return
                }

                let sorted = people.sorted {
                    $0.fullName.localizedCaseInsensitiveCompare($1.fullName) == .orderedAscending
                }
                continuation.resume(returning: sorted)
            }
        }
    }
}
