import Foundation
import Security

/// Cosa può andare storto parlando con il Portachiavi.
enum KeychainError: Error, Equatable {
    case notFound
    case encodingFailed
    case decodingFailed
    /// Il Portachiavi ha risposto con un codice di errore di sistema.
    case unexpectedStatus(OSStatus)

    var message: String {
        switch self {
        case .notFound:
            return "Dato non presente nel Portachiavi"
        case .encodingFailed:
            return "Impossibile preparare il dato per il Portachiavi"
        case .decodingFailed:
            return "Il dato nel Portachiavi non è leggibile"
        case .unexpectedStatus(let status):
            return "Il Portachiavi ha rifiutato l'operazione (codice \(status))"
        }
    }
}

/// L'archivio sicuro, dietro un protocollo così che i test possano
/// sostituirlo con una versione in memoria senza toccare il Portachiavi vero.
protocol SecureStoring: AnyObject {
    func save<T: Encodable>(_ value: T, for key: String) throws
    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> T
    func delete(_ key: String) throws
    func contains(_ key: String) -> Bool
}

/// Il Portachiavi di iOS.
///
/// Le coordinate bancarie stanno qui e non in `UserDefaults`: il Portachiavi
/// è cifrato, resta inaccessibile a dispositivo bloccato e — con
/// `WhenUnlockedThisDeviceOnly` — non viene copiato nei backup verso altri
/// dispositivi. È anche il motivo per cui, dopo un ripristino da backup, il
/// conto va ricollegato: il dato per definizione non ha viaggiato.
final class KeychainStore: SecureStoring {

    private let service: String

    init(service: String = "com.cash.app.secure-store") {
        self.service = service
    }

    func save<T: Encodable>(_ value: T, for key: String) throws {
        guard let data = try? JSONEncoder().encode(value) else {
            throw KeychainError.encodingFailed
        }

        // Il Portachiavi non ha un "inserisci o aggiorna": si cancella e si
        // riscrive. La cancellazione di una chiave assente non è un errore.
        try? delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> T {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw KeychainError.decodingFailed }
            guard let decoded = try? JSONDecoder().decode(type, from: data) else {
                throw KeychainError.decodingFailed
            }
            return decoded
        case errSecItemNotFound:
            throw KeychainError.notFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func contains(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }
}
