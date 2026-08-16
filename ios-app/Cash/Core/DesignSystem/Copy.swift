import Foundation

/// I testi che compaiono dentro la sequenza di pagamento.
enum Copy {

    /// La conferma finale del video di riferimento era in inglese
    /// ("Sent to Natalie"). Ora che la stessa schermata ha pulsanti in
    /// italiano, mescolare le lingue stonerebbe. `true` torna all'inglese.
    static let usesVideoWording = false

    static func sent(to name: String) -> String {
        usesVideoWording ? "Sent to \(name)" : "Inviato a \(name)"
    }

    /// La dicitura in alto a sinistra sulla banconota resta sempre così: è il
    /// nome dell'app stampato sulla carta, non una parola da tradurre.
    static let noteKind = "CASH"

    static let confirmPayment = "Conferma pagamento"
    static let editAmount = "Modifica importo"
    static let continueToConfirmation = "Continua"
}
