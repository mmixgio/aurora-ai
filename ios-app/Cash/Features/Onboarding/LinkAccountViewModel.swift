import Foundation
import SwiftUI

/// La logica del collegamento del conto, fuori dalla vista.
///
/// Formattazione, validazione e decisione su *quando* mostrare l'errore
/// stanno qui: la schermata si limita a disegnare due campi e un pulsante.
@MainActor
final class LinkAccountViewModel: ObservableObject {

    @Published var holderName = ""

    @Published var ibanInput = "" {
        didSet {
            // Riformatta mentre si scrive. La funzione è idempotente, quindi
            // riassegnare il valore non innesca un ciclo.
            let formatted = IBANValidator.formatted(ibanInput)
            if formatted != ibanInput { ibanInput = formatted }
        }
    }

    /// `true` mentre il campo IBAN ha il fuoco.
    @Published var isEditingIBAN = false

    private var validation: Result<String, IBANValidator.ValidationError> {
        IBANValidator.validate(ibanInput)
    }

    var isIBANValid: Bool {
        if case .success = validation { return true }
        return false
    }

    /// L'errore si mostra solo quando ha senso mostrarlo: mentre si sta
    /// ancora scrivendo l'IBAN è ovviamente incompleto, e segnalarlo a ogni
    /// tasto sarebbe solo rumore rosso sotto il campo.
    var visibleError: String? {
        guard !ibanInput.isEmpty, !isEditingIBAN else { return nil }
        if case .failure(let error) = validation { return error.message }
        return nil
    }

    var trimmedHolder: String {
        holderName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        isIBANValid && !trimmedHolder.isEmpty
    }

    /// Costruisce il conto da collegare, o `nil` se i dati non bastano.
    func makeAccount() -> BankAccount? {
        guard canSubmit, case .success(let compacted) = validation else { return nil }
        return BankAccount(holderName: trimmedHolder, iban: compacted)
    }
}
