import Foundation
import SwiftUI

/// La navigazione dell'app, in un solo posto.
///
/// Le viste non aprono e chiudono schermate a vicenda con booleani sparsi:
/// chiedono al router. Così il percorso completo — home, contatti, pagamento,
/// ritorno — è leggibile in venti righe invece che rincorso in cinque file.
@MainActor
final class AppRouter: ObservableObject {

    /// Le schermate presentate sopra la home.
    enum Sheet: Identifiable, Equatable {
        case requestMoney
        case settings

        var id: String {
            switch self {
            case .requestMoney: return "request"
            case .settings:     return "settings"
            }
        }
    }

    /// Il flusso di pagamento occupa tutto lo schermo: da lì in poi non deve
    /// esserci nient'altro, né barre né bordi della home che si intravedono.
    @Published var isPresentingPaymentFlow = false

    @Published var sheet: Sheet?

    /// Il percorso dentro il flusso di pagamento: vuoto = scelta destinatario,
    /// un elemento = schermata di pagamento per quella persona.
    @Published var paymentPath: [ContactPerson] = []

    // MARK: - Comandi

    func startPayment() {
        paymentPath = []
        isPresentingPaymentFlow = true
    }

    func choose(recipient: ContactPerson) {
        paymentPath = [recipient]
    }

    /// Chiude il flusso e ripulisce il percorso, così la volta dopo si
    /// riparte dalla scelta del destinatario e non dall'ultimo pagamento.
    func finishPayment() {
        isPresentingPaymentFlow = false
        paymentPath = []
    }

    func present(_ sheet: Sheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }
}
