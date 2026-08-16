import Foundation
import Security

/// Archivio per i dati che non devono finire in chiaro sul telefono.
///
/// Le coordinate bancarie stanno qui e non in `UserDefaults`: il Portachiavi
/// è cifrato, resta protetto quando il telefono è bloccato, e non viene
/// copiato nei backup verso altri dispositivi
/// (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`).
enum KeychainStore {

    private static let service = "com.cash.app.secure-store"

    @discardableResult
    static func save(_ data: Data, for key: String) -> Bool {
        // Il Portachiavi non ha un "aggiorna o inserisci": si cancella e si riscrive.
        delete(key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(_ key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    @discardableResult
    static func delete(_ key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Comodità per i tipi Codable

    @discardableResult
    static func encode<T: Encodable>(_ value: T, for key: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return save(data, for: key)
    }

    static func decode<T: Decodable>(_ type: T.Type, for key: String) -> T? {
        guard let data = load(key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
