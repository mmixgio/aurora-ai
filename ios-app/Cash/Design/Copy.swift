import Foundation

/// I testi che compaiono dentro la sequenza di pagamento.
///
/// Nel video sono in inglese e fanno parte del design tanto quanto il nero e
/// la banconota, quindi di default l'app li lascia esattamente com'erano.
/// Mettendo `usesVideoWording` a `false` passano tutti in italiano.
enum Copy {

    static let usesVideoWording = true

    /// La scritta accanto all'importo, con l'a capo del video.
    static var payHint: String {
        usesVideoWording ? "Double Click\nto Pay" : "Tocca due volte\nper pagare"
    }

    /// La conferma finale.
    static func sent(to name: String) -> String {
        usesVideoWording ? "Sent to \(name)" : "Inviato a \(name)"
    }

    /// L'etichetta in alto a sinistra sulla banconota.
    static var noteKind: String {
        usesVideoWording ? "CASH" : "CONTANTI"
    }
}
