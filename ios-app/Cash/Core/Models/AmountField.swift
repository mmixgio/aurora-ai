import Foundation

/// Quale parte dell'importo stanno regolando i tasti del volume.
///
/// Toccare la parte decimale sposta qui la selezione: da quel momento un
/// colpo di volume vale un centesimo invece di un euro. È l'unico modo per
/// inserire i centesimi senza rimettere a schermo un tastierino.
enum AmountField: Equatable, CaseIterable, Sendable {
    case units
    case cents

    /// Di quanti centesimi si muove l'importo a ogni pressione.
    var stepInCents: Int64 {
        switch self {
        case .units: return 100
        case .cents: return 1
        }
    }

    var accessibilityName: String {
        switch self {
        case .units: return "Euro"
        case .cents: return "Centesimi"
        }
    }
}
