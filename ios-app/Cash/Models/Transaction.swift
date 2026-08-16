import Foundation

/// Un movimento nello storico.
struct Transaction: Identifiable, Codable, Hashable {

    enum Direction: String, Codable {
        case sent
        case received
    }

    let id: UUID
    let direction: Direction

    /// Il nome dell'altra persona, congelato al momento del movimento.
    ///
    /// Volutamente una copia e non un riferimento al contatto: se domani
    /// cancelli Natalie dalla rubrica, lo storico deve continuare a dire
    /// "Natalie", non "Sconosciuto".
    let counterpartName: String

    let amount: Money
    let date: Date

    /// Il numero di serie stampato sulla banconota, tenuto per poterla
    /// ricostruire identica quando riapri il movimento nello storico.
    let serial: String

    init(
        id: UUID = UUID(),
        direction: Direction,
        counterpartName: String,
        amount: Money,
        date: Date = Date(),
        serial: String = Transaction.makeSerial()
    ) {
        self.id = id
        self.direction = direction
        self.counterpartName = counterpartName
        self.amount = amount
        self.date = date
        self.serial = serial
    }

    /// L'importo con il segno davanti, come va mostrato nella lista.
    var signedAmountText: String {
        let formatted = amount.formatted()
        return direction == .sent ? "-\(formatted)" : "+\(formatted)"
    }

    /// "Oggi 14:32", "Ieri 09:10", oppure la data estesa.
    var dateText: String {
        let calendar = Calendar.current
        let time = Transaction.timeFormatter.string(from: date)

        if calendar.isDateInToday(date) { return "Oggi \(time)" }
        if calendar.isDateInYesterday(date) { return "Ieri \(time)" }
        return Transaction.dateFormatter.string(from: date)
    }

    /// Otto caratteri alfanumerici, come il numero di serie di una banconota vera.
    static func makeSerial() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<8).map { _ in alphabet.randomElement() ?? "0" })
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "it_IT")
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter
    }()
}
