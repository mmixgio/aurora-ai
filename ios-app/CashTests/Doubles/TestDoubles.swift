import Foundation
@testable import Cash

/// Persistenza in memoria.
///
/// I test non devono toccare `UserDefaults.standard`: renderebbe ogni caso
/// dipendente dall'ordine di esecuzione e dai residui del precedente.
final class InMemoryStore: LocalPersisting {

    var storedTransactions: [Transaction] = []
    var storedOpeningBalance: Money = AppConfiguration.initialBalance
    var storedSignature = UserSignature.fallback
    var storedOnboarding = false

    /// Se valorizzato, la lettura fallisce: serve a esercitare il percorso
    /// "storico illeggibile" senza corrompere un file davvero.
    var loadError: PersistenceError?

    /// Se valorizzato, la scrittura fallisce.
    var saveError: PersistenceError?

    private(set) var saveCount = 0

    func loadTransactions() throws -> [Transaction] {
        if let loadError { throw loadError }
        return storedTransactions
    }

    func store(transactions: [Transaction]) throws {
        if let saveError { throw saveError }
        storedTransactions = transactions
        saveCount += 1
    }

    func loadOpeningBalance() -> Money { storedOpeningBalance }
    func store(openingBalance: Money) { storedOpeningBalance = openingBalance }

    func loadSignature() -> String { storedSignature }
    func store(signature: String) { storedSignature = signature }

    func loadOnboardingCompleted() -> Bool { storedOnboarding }
    func store(onboardingCompleted: Bool) { storedOnboarding = onboardingCompleted }

    func reset() {
        storedTransactions = []
        storedOpeningBalance = AppConfiguration.initialBalance
        storedSignature = UserSignature.fallback
        storedOnboarding = false
    }
}

/// Portachiavi finto.
final class InMemorySecureStore: SecureStoring {

    private var items: [String: Data] = [:]
    var failNextSave = false

    func save<T: Encodable>(_ value: T, for key: String) throws {
        if failNextSave {
            failNextSave = false
            throw KeychainError.unexpectedStatus(-25299)
        }
        guard let data = try? JSONEncoder().encode(value) else {
            throw KeychainError.encodingFailed
        }
        items[key] = data
    }

    func load<T: Decodable>(_ type: T.Type, for key: String) throws -> T {
        guard let data = items[key] else { throw KeychainError.notFound }
        guard let decoded = try? JSONDecoder().decode(type, from: data) else {
            throw KeychainError.decodingFailed
        }
        return decoded
    }

    func delete(_ key: String) throws { items.removeValue(forKey: key) }
    func contains(_ key: String) -> Bool { items[key] != nil }
}

/// Autorizzatore pilotabile: approva, annulla o lancia a comando.
final class StubAuthorizer: PaymentAuthorizing {

    enum Behaviour {
        case approve
        case cancel
        case fail(BiometricError)
    }

    var behaviour: Behaviour = .approve
    var method: AuthorizationMethod = .local(.faceID)
    private(set) var authorizeCallCount = 0

    func authorize(amount: Money, recipientName: String) async throws -> AuthorizationOutcome {
        authorizeCallCount += 1
        switch behaviour {
        case .approve: return .approved
        case .cancel:  return .cancelled
        case .fail(let error): throw error
        }
    }
}

/// Registro finto per la macchina a stati.
@MainActor
final class StubLedger: PaymentLedger {

    var validationMessage: String?
    var commitResult: Result<Transaction, TransactionStore.StoreError>?
    private(set) var committedDrafts: [PaymentDraft] = []

    func validate(amount: Money) -> String? { validationMessage }

    func commit(_ draft: PaymentDraft) -> Result<Transaction, TransactionStore.StoreError> {
        committedDrafts.append(draft)
        if let commitResult { return commitResult }
        return .success(draft.makeTransaction())
    }
}

/// Servizio volume finto, che non tocca l'audio.
@MainActor
final class StubVolumeService: HardwareVolumeObserving {

    var startError: Error?
    private(set) var isListening = false
    private(set) var stopCount = 0
    private var handler: ((VolumeButtonDirection) -> Void)?

    func start(onPress: @escaping (VolumeButtonDirection) -> Void) throws {
        if let startError { throw startError }
        handler = onPress
        isListening = true
    }

    func stop() {
        handler = nil
        isListening = false
        stopCount += 1
    }

    /// Simula una pressione del tasto fisico.
    func press(_ direction: VolumeButtonDirection) {
        handler?(direction)
    }
}

/// Rubrica finta.
final class StubContactsService: ContactsProviding, @unchecked Sendable {

    var status: ContactsAccess = .notDetermined
    var grantOnRequest = true
    var people: [ContactPerson] = []
    var fetchError: ContactsError?

    func authorizationStatus() -> ContactsAccess { status }

    func requestAccess() async -> ContactsAccess {
        status = grantOnRequest ? .authorized : .denied
        return status
    }

    func fetchContacts() async throws -> [ContactPerson] {
        if let fetchError { throw fetchError }
        return people
    }
}

// MARK: - Costruttori di comodo

extension ContactPerson {
    static func fixture(
        id: String = UUID().uuidString,
        given: String = "Natalie",
        family: String = "Rossi"
    ) -> ContactPerson {
        ContactPerson(id: id, givenName: given, familyName: family)
    }
}

extension Transaction {
    static func fixture(
        id: UUID = UUID(),
        direction: PaymentDirection = .sent,
        name: String = "Natalie Rossi",
        amount: Money = Money(units: 20),
        date: Date = Date(),
        serial: String = "ABCD2345"
    ) -> Transaction {
        Transaction(
            id: id,
            direction: direction,
            counterpartName: name,
            amount: amount,
            date: date,
            serial: serial
        )
    }
}
